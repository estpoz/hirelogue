import AVFAudio
import Foundation
import Speech

// MARK: - Speech Transcription Contract

@MainActor
protocol SpeechTranscriptionService: AnyObject {
    func requestSpeechRecognitionPermission() async -> Bool
    func startTranscribing(onTranscriptChange: @escaping @MainActor (String) -> Void) async throws
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

    func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing(onTranscriptChange: @escaping @MainActor (String) -> Void) async throws {
        _ = await stopTranscribing()
        latestTranscript = ""

        do {
            try await startSpeechAnalyzerTranscription(onTranscriptChange: onTranscriptChange)
        } catch {
            print("Hirelogue SpeechAnalyzer unavailable, falling back to SFSpeechRecognizer: \(error.localizedDescription)")
            _ = await stopTranscribing()
            latestTranscript = ""
            try await startLegacyTranscription(onTranscriptChange: onTranscriptChange)
        }
    }

    func stopTranscribing() async -> String {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil

        analysisTask?.cancel()
        resultsTask?.cancel()
        analysisTask = nil
        resultsTask = nil

        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }

        legacyRecognitionRequest?.endAudio()
        legacyRecognitionTask?.finish()
        legacyRecognitionRequest = nil
        legacyRecognitionTask = nil

        analyzer = nil
        transcriber = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - SpeechAnalyzer Path

    /// Preferred on-device path. This can fail when SpeechAnalyzer assets are unavailable.
    private func startSpeechAnalyzerTranscription(onTranscriptChange: @escaping @MainActor (String) -> Void) async throws {
        let preferredLocale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_US"))
        let currentLocale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
        let locale = preferredLocale ?? currentLocale

        guard let locale else {
            throw SpeechTranscriptionError.unsupportedLocale
        }

        // progressive -> can return partial text when user still talking
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        try await prepareAssets(for: transcriber)

        let microphoneFormat = try await prepareAudioSessionAndMicrophoneFormat()
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: microphoneFormat
        ) else {
            throw SpeechTranscriptionError.unsupportedAnalyzerFormat
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        let (inputSequence, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        self.analyzer = analyzer
        self.transcriber = transcriber
        self.inputContinuation = inputContinuation

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let transcript = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)

                    await MainActor.run {
                        self?.latestTranscript = transcript
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

    // MARK: - Asset Preparation

    private func prepareAssets(for transcriber: SpeechTranscriber) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    // MARK: - Legacy SFSpeechRecognizer Fallback

    /// Fallback path for devices or simulators where SpeechAnalyzer assets cannot be reserved.
    private func startLegacyTranscription(onTranscriptChange: @escaping @MainActor (String) -> Void) async throws {
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US")), speechRecognizer.isAvailable else {
            throw SpeechTranscriptionError.legacyRecognizerUnavailable
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

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
