import AVFAudio
import Foundation
import Speech

// MARK: - Speech Transcription Contract

struct SpeechTranscriptionContext {
    let jobProfile: JobProfile?
    let question: InterviewQuestion
    let promptText: String
    let isFollowUp: Bool

    var contextualStrings: [String] {
        var candidates = [
            jobProfile?.position,
            jobProfile?.seniority,
            question.competency,
            question.text,
            question.followUp,
            promptText,
            isFollowUp ? "follow up question" : "primary question"
        ]

        if let jobProfile {
            candidates.append(contentsOf: jobProfile.responsibilities)
            candidates.append(contentsOf: jobProfile.requiredQualifications)
            candidates.append(contentsOf: jobProfile.preferredQualifications)
            candidates.append(contentsOf: jobProfile.technicalCompetencies)
            candidates.append(contentsOf: jobProfile.behavioralCompetencies)
        }

        return Array(Set(candidates.compactMap { candidate in
            let cleaned = candidate?
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .punctuationCharacters)

            guard let cleaned, cleaned.count >= 2 else { return nil }
            return cleaned
        }))
        .sorted()
    }
}

@MainActor
protocol SpeechTranscriptionService: AnyObject {
    func requestSpeechRecognitionPermission() async -> Bool
    func startTranscribing(
        context: SpeechTranscriptionContext,
        onTranscriptChange: @escaping @MainActor (String) -> Void
    ) async throws
    func stopTranscribing() async -> String
}

// MARK: - Speech Transcription Errors

enum SpeechTranscriptionError: LocalizedError {
    case unsupportedLocale
    case analyzerUnavailable
    case invalidMicrophoneFormat
    case unsupportedAnalyzerFormat
    case audioConversionFailed
    case legacyRecognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale:
            "Speech transcription is not available for the current locale."
        case .analyzerUnavailable:
            "Speech analyzer could not be started."
        case .invalidMicrophoneFormat:
            "The current microphone route does not provide a valid audio format. Try running on a physical device or reconnecting the microphone."
        case .unsupportedAnalyzerFormat:
            "SpeechAnalyzer could not provide a compatible audio format for transcription."
        case .audioConversionFailed:
            "Microphone audio could not be converted for speech transcription."
        case .legacyRecognizerUnavailable:
            "Speech recognition is not currently available. Check your network connection or try again later."
        }
    }
}

// MARK: - Audio Conversion Helper

private final class OneShotAudioBufferProvider: @unchecked Sendable {
    nonisolated(unsafe) private var buffer: AVAudioPCMBuffer?

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    nonisolated func nextBuffer(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard let buffer else {
            status.pointee = .noDataNow
            return nil
        }

        self.buffer = nil
        status.pointee = .haveData
        return buffer
    }
}

// MARK: - SpeechAnalyzer Implementation

@MainActor
final class SpeechAnalyzerTranscriptionService: SpeechTranscriptionService {
    private let audioEngine = AVAudioEngine()

    // SpeechAnalyzer
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    
    // fallback recognizer (SFSpeechAudio)
    private var legacyRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var legacyRecognitionTask: SFSpeechRecognitionTask?
    
    private var latestTranscript = ""
    private var finalizedTranscriptSegments: [String] = []
    private var volatileTranscriptSegment: String?
    private var contextualTerms: Set<String> = []
    private let finalizationDelayNanoseconds: UInt64 = 700_000_000

    func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing(
        context: SpeechTranscriptionContext,
        onTranscriptChange: @escaping @MainActor (String) -> Void
    ) async throws {
        _ = await stopTranscribing()
        latestTranscript = ""
        finalizedTranscriptSegments = []
        volatileTranscriptSegment = nil
        contextualTerms = Self.normalizedContextualTerms(from: context.contextualStrings)

        do {
            try await startSpeechAnalyzerTranscription(
                context: context,
                onTranscriptChange: onTranscriptChange
            )
        } catch {
            print("Hirelogue SpeechAnalyzer unavailable, falling back to SFSpeechRecognizer: \(error.localizedDescription)")
            _ = await stopTranscribing()
            latestTranscript = ""
            finalizedTranscriptSegments = []
            volatileTranscriptSegment = nil
            try await startLegacyTranscription(
                context: context,
                onTranscriptChange: onTranscriptChange
            )
        }
    }

    func stopTranscribing() async -> String {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil

        legacyRecognitionRequest?.endAudio()
        legacyRecognitionTask?.finish()

        if analyzer != nil || legacyRecognitionTask != nil {
            try? await Task.sleep(nanoseconds: finalizationDelayNanoseconds)
        }

        analysisTask?.cancel()
        resultsTask?.cancel()
        analysisTask = nil
        resultsTask = nil

        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }

        legacyRecognitionRequest = nil
        legacyRecognitionTask = nil

        analyzer = nil
        transcriber = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - SpeechAnalyzer Path

    /// Preferred on-device path. This can fail when SpeechAnalyzer assets are unavailable.
    private func startSpeechAnalyzerTranscription(
        context: SpeechTranscriptionContext,
        onTranscriptChange: @escaping @MainActor (String) -> Void
    ) async throws {
        let preferredLocale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_US"))
        let currentLocale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
        let locale = preferredLocale ?? currentLocale

        guard let locale else {
            throw SpeechTranscriptionError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .alternativeTranscriptions],
            attributeOptions: [.transcriptionConfidence]
        )
        try await prepareAssets(for: transcriber)

        let microphoneFormat = try await prepareAudioSessionAndMicrophoneFormat()
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: microphoneFormat
        ) else {
            throw SpeechTranscriptionError.unsupportedAnalyzerFormat
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.setContext(analysisContext(for: context))
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        let (inputSequence, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        self.analyzer = analyzer
        self.transcriber = transcriber
        self.inputContinuation = inputContinuation

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let transcriptSegment = self?.bestTranscriptCandidate(
                        primary: result.text,
                        alternatives: result.alternatives
                    ) ?? String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)

                    await MainActor.run {
                        guard let self else { return }
                        let transcript = self.ingestSpeechAnalyzerTranscriptSegment(
                            transcriptSegment,
                            isFinal: result.isFinal
                        )
                        onTranscriptChange(transcript)
                    }
                }
            } catch {
                print("Hirelogue transcription result error: \(error.localizedDescription)")
            }
        }

        try startAudioCapture(
            inputContinuation: inputContinuation,
            microphoneFormat: microphoneFormat,
            analyzerFormat: analyzerFormat
        )

        analysisTask = Task {
            do {
                try await analyzer.start(inputSequence: inputSequence)
            } catch {
                print("Hirelogue speech analyzer error: \(error.localizedDescription)")
            }
        }
    }

    /// Biases SpeechAnalyzer toward role-specific terms such as framework names, competencies, and the current question.
    private func analysisContext(for context: SpeechTranscriptionContext) -> AnalysisContext {
        let analysisContext = AnalysisContext()
        analysisContext.contextualStrings[.general] = context.contextualStrings
        return analysisContext
    }

    // MARK: - Asset Preparation

    private func prepareAssets(for transcriber: SpeechTranscriber) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    // MARK: - Legacy SFSpeechRecognizer Fallback

    /// Fallback path for devices or simulators where SpeechAnalyzer assets cannot be reserved.
    private func startLegacyTranscription(
        context: SpeechTranscriptionContext,
        onTranscriptChange: @escaping @MainActor (String) -> Void
    ) async throws {
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US")), speechRecognizer.isAvailable else {
            throw SpeechTranscriptionError.legacyRecognizerUnavailable
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        recognitionRequest.taskHint = .dictation
        recognitionRequest.contextualStrings = context.contextualStrings

        let microphoneFormat = try await prepareAudioSessionAndMicrophoneFormat()
        let inputNode = audioEngine.inputNode

        print("Hirelogue transcription starting with legacy SFSpeechRecognizer fallback.")
        legacyRecognitionRequest = recognitionRequest
        legacyRecognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result {
                let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { @MainActor in
                    self?.latestTranscript = transcript
                    onTranscriptChange(transcript)
                }
            }

            if let error {
                print("Hirelogue legacy speech recognition error: \(error.localizedDescription)")
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: microphoneFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Transcript Candidate Selection

    private func ingestSpeechAnalyzerTranscriptSegment(_ segment: String, isFinal: Bool) -> String {
        let cleanedSegment = Self.normalizedTranscriptText(segment)
        guard !cleanedSegment.isEmpty else { return latestTranscript }

        if isFinal {
            commitFinalizedTranscriptSegment(cleanedSegment)
            volatileTranscriptSegment = nil
        } else if let volatileTranscriptSegment, !isRevision(cleanedSegment, of: volatileTranscriptSegment) {
            commitFinalizedTranscriptSegment(volatileTranscriptSegment)
            self.volatileTranscriptSegment = cleanedSegment
        } else {
            volatileTranscriptSegment = cleanedSegment
        }

        latestTranscript = joinedTranscript()
        return latestTranscript
    }

    private func commitFinalizedTranscriptSegment(_ segment: String) {
        let cleanedSegment = Self.normalizedTranscriptText(segment)
        guard !cleanedSegment.isEmpty else { return }

        if let lastSegment = finalizedTranscriptSegments.last {
            if lastSegment == cleanedSegment || lastSegment.contains(cleanedSegment) {
                return
            }

            if cleanedSegment.contains(lastSegment) {
                finalizedTranscriptSegments[finalizedTranscriptSegments.count - 1] = cleanedSegment
                return
            }
        }

        if joinedTranscript().contains(cleanedSegment) {
            return
        }

        finalizedTranscriptSegments.append(cleanedSegment)
    }

    private func joinedTranscript() -> String {
        var segments = finalizedTranscriptSegments
        if let volatileTranscriptSegment {
            segments.append(volatileTranscriptSegment)
        }

        return Self.normalizedTranscriptText(segments.joined(separator: " "))
    }

    private func isRevision(_ candidate: String, of existingSegment: String) -> Bool {
        if candidate.hasPrefix(existingSegment) || existingSegment.hasPrefix(candidate) {
            return true
        }

        let candidateWords = Set(Self.normalizedWords(in: candidate))
        let existingWords = Set(Self.normalizedWords(in: existingSegment))
        guard !candidateWords.isEmpty, !existingWords.isEmpty else { return false }

        let sharedWords = candidateWords.intersection(existingWords).count
        let shorterCount = min(candidateWords.count, existingWords.count)
        return Double(sharedWords) / Double(shorterCount) >= 0.6
    }

    private func bestTranscriptCandidate(primary: AttributedString, alternatives: [AttributedString]) -> String {
        let candidates = ([primary] + alternatives)
            .map { String($0.characters).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let primaryCandidate = candidates.first else { return "" }
        let primaryScore = contextMatchScore(for: primaryCandidate)

        return candidates.dropFirst().reduce(primaryCandidate) { currentBest, candidate in
            let currentScore = contextMatchScore(for: currentBest)
            let candidateScore = contextMatchScore(for: candidate)
            let candidateIsMeaningfullyBetter = candidateScore >= max(primaryScore + 2, currentScore + 2)
            return candidateIsMeaningfullyBetter ? candidate : currentBest
        }
    }

    private func contextMatchScore(for transcript: String) -> Int {
        let normalizedTranscript = transcript.lowercased()
        return contextualTerms.reduce(0) { score, term in
            normalizedTranscript.contains(term) ? score + 1 : score
        }
    }

    private static func normalizedContextualTerms(from strings: [String]) -> Set<String> {
        let words = strings.flatMap { normalizedWords(in: $0) }
        return Set(words)
    }

    private static func normalizedWords(in text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }

    private static func normalizedTranscriptText(_ transcript: String) -> String {
        transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Audio Capture

    /// Activates the recording session, lets the route settle, and verifies Core Audio exposes a usable input format.
    private func prepareAudioSessionAndMicrophoneFormat() async throws -> AVAudioFormat {
        let audioSession = AVAudioSession.sharedInstance()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()

        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        for _ in 1...8 {
            let microphoneFormat = audioEngine.inputNode.inputFormat(forBus: 0)

            if microphoneFormat.sampleRate > 0, microphoneFormat.channelCount > 0 {
                return microphoneFormat
            }

            try await Task.sleep(nanoseconds: 150_000_000)
        }

        throw SpeechTranscriptionError.invalidMicrophoneFormat
    }

    /// Captures microphone buffers, converts them to SpeechAnalyzer's preferred format, then streams them for transcription.
    private func startAudioCapture(
        inputContinuation: AsyncStream<AnalyzerInput>.Continuation,
        microphoneFormat: AVAudioFormat,
        analyzerFormat: AVAudioFormat
    ) throws {
        let inputNode = audioEngine.inputNode
        guard let converter = AVAudioConverter(from: microphoneFormat, to: analyzerFormat) else {
            throw SpeechTranscriptionError.audioConversionFailed
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: microphoneFormat) { buffer, _ in
            let sampleRateRatio = analyzerFormat.sampleRate / microphoneFormat.sampleRate
            let convertedFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * sampleRateRatio) + 1

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: analyzerFormat,
                frameCapacity: convertedFrameCapacity
            ) else {
                return
            }

            var conversionError: NSError?
            let bufferProvider = OneShotAudioBufferProvider(buffer: buffer)
            let inputBlock: AVAudioConverterInputBlock = { _, outputStatus in
                bufferProvider.nextBuffer(status: outputStatus)
            }

            converter.convert(to: convertedBuffer, error: &conversionError, withInputFrom: inputBlock)

            guard conversionError == nil, convertedBuffer.frameLength > 0 else {
                if let conversionError {
                    print("Hirelogue audio conversion error: \(conversionError.localizedDescription)")
                }
                return
            }

            inputContinuation.yield(AnalyzerInput(buffer: convertedBuffer))
        }

        audioEngine.prepare()
        try audioEngine.start()
    }
}
