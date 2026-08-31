import AVFAudio
import Foundation
import Observation

/// Owns all mutable state for the app-base interview flow.
///
/// The current milestone uses static fixtures and timers. Future AI, speech, and
/// audio services should plug in here or behind services called by this object,
/// keeping views focused on rendering state.
@MainActor
@Observable
final class InterviewSessionViewModel {
    // MARK: - Home and Analysis State

    var jobOpening = ""
    var jobProfile: JobProfile?

    // MARK: - Interview Configuration

    var interviewType: InterviewType = .mixed
    var duration: InterviewDuration = .ten

    // MARK: - Loading and Permission State

    var isAnalyzing = false
    var analysisProgress = 0.0
    /// Status text shown while the async analyzer prepares a profile.
    var analysisStatusMessage = "Identifying the role, qualifications, and interview competencies."
    /// Non-nil when the app had to use prototype fallback data instead of a Foundation Models result.
    var analysisErrorMessage: String?
    var isRequestingMicrophonePermission = false
    /// True while Foundation Models is generating the question plan from the edited setup profile.
    var isGeneratingInterviewQuestions = false
    /// Non-nil when question generation falls back to prototype questions.
    var questionGenerationErrorMessage: String?
    /// Non-nil when live speech transcription cannot start or permission is denied.
    var transcriptionErrorMessage: String?
    /// Non-nil when answer review falls back to continuing without a follow-up.
    var followUpGenerationErrorMessage: String?
    /// True while Foundation Models is generating final interview feedback.
    var isGeneratingFeedback = false
    /// Non-nil when final feedback falls back to prototype feedback.
    var feedbackGenerationErrorMessage: String?

    // MARK: - Interview Session State

    var phase: InterviewPhase = .speaking
    var questionIndex = 0
    var isFollowUp = false
    var pauseCountdown = 3
    var secondsRemaining = InterviewDuration.ten.rawValue * 60
    var completed = false
    var shouldShowFeedback = false
    /// Temporary validation surface: shows what SpeechAnalyzer hears while the candidate answers.
    var liveTranscript = ""
    /// True only while microphone audio is actively being streamed to SpeechAnalyzer.
    var isTranscribing = false
    /// Dynamic follow-up generated from the current transcribed answer.
    var generatedFollowUpQuestion: String?
    /// Captured transcripts for the completed primary questions and their optional follow-ups.
    var answerHistory: [InterviewAnswer] = []

    // MARK: - Feedback State

    var questions = MockHirelogueData.questions
    var feedback = MockHirelogueData.feedback

    // MARK: - Services

    /// Primary analyzer used by Home. Injected so tests/previews can provide deterministic services later.
    @ObservationIgnored private let jobAnalysisService: any JobAnalysisService
    /// Keeps the prototype usable on devices where Apple Intelligence is unavailable.
    @ObservationIgnored private let fallbackJobAnalysisService: any JobAnalysisService
    /// Generates role-specific questions from the edited setup profile.
    @ObservationIgnored private let interviewQuestionService: any InterviewQuestionService
    /// Keeps the interview flow usable when Foundation Models question generation fails.
    @ObservationIgnored private let fallbackInterviewQuestionService: any InterviewQuestionService
    /// Speaks interviewer prompts aloud during the session's speaking phase.
    @ObservationIgnored private let speechSynthesisService: any SpeechSynthesisService
    /// Streams the candidate's spoken answers into visible live text during listening.
    @ObservationIgnored private let speechTranscriptionService: any SpeechTranscriptionService
    /// Reviews transcribed answers and generates one follow-up question when needed.
    @ObservationIgnored private let answerFollowUpService: any AnswerFollowUpService
    /// Keeps the interview moving if Foundation Models cannot review an answer.
    @ObservationIgnored private let fallbackAnswerFollowUpService: any AnswerFollowUpService
    /// Generates the structured feedback shown after a completed interview.
    @ObservationIgnored private let interviewFeedbackService: any InterviewFeedbackService
    /// Keeps the final screen usable when Foundation Models feedback generation fails.
    @ObservationIgnored private let fallbackInterviewFeedbackService: any InterviewFeedbackService

    // MARK: - Internal Tasks

    /// Unstructured tasks drive analysis and short prototype delays and must be cancelled
    /// when the user restarts, exits, or jumps between demo states.
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var phaseTask: Task<Void, Never>?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var remainingTimeTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var currentAnswerTranscriptSegments: [String] = []
    @ObservationIgnored private var currentAnswerTranscript = ""
    @ObservationIgnored private var bestPartialTranscript = ""
    @ObservationIgnored private let silenceWarningInterval: TimeInterval = 3
    @ObservationIgnored private let silenceFinalizeInterval: TimeInterval = 3
    @ObservationIgnored private var lastTranscriptActivityDate = Date()

    init(
        jobAnalysisService: any JobAnalysisService = FoundationModelJobAnalysisService(),
        fallbackJobAnalysisService: any JobAnalysisService = MockJobAnalysisService(),
        interviewQuestionService: any InterviewQuestionService = FoundationModelInterviewQuestionService(),
        fallbackInterviewQuestionService: any InterviewQuestionService = MockInterviewQuestionService(),
        speechSynthesisService: (any SpeechSynthesisService)? = nil,
        speechTranscriptionService: (any SpeechTranscriptionService)? = nil,
        answerFollowUpService: any AnswerFollowUpService = FoundationModelAnswerFollowUpService(),
        fallbackAnswerFollowUpService: any AnswerFollowUpService = MockAnswerFollowUpService(),
        interviewFeedbackService: any InterviewFeedbackService = FoundationModelInterviewFeedbackService(),
        fallbackInterviewFeedbackService: any InterviewFeedbackService = MockInterviewFeedbackService()
    ) {
        self.jobAnalysisService = jobAnalysisService
        self.fallbackJobAnalysisService = fallbackJobAnalysisService
        self.interviewQuestionService = interviewQuestionService
        self.fallbackInterviewQuestionService = fallbackInterviewQuestionService
        self.speechSynthesisService = speechSynthesisService ?? InterviewSpeechSynthesisService()
        self.speechTranscriptionService = speechTranscriptionService ?? SpeechAnalyzerTranscriptionService()
        self.answerFollowUpService = answerFollowUpService
        self.fallbackAnswerFollowUpService = fallbackAnswerFollowUpService
        self.interviewFeedbackService = interviewFeedbackService
        self.fallbackInterviewFeedbackService = fallbackInterviewFeedbackService
    }

    // MARK: - Derived Display State

    /// Whether the Home screen's primary action can run.
    var canAnalyze: Bool {
        !jobOpening.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    /// The active question, clamped so display code remains safe at the end.
    var currentQuestion: InterviewQuestion {
        questions[min(questionIndex, questions.count - 1)]
    }

    /// Current prompt text, using the follow-up when the phase machine requests it.
    var currentQuestionText: String {
        if isFollowUp, let generatedFollowUpQuestion {
            return generatedFollowUpQuestion
        }

        if isFollowUp, let followUp = currentQuestion.followUp {
            return followUp
        }
        return currentQuestion.text
    }

    /// Human-readable question count for the interview header.
    var questionProgressTitle: String {
        let number = min(questionIndex + 1, questions.count)
        return "Question \(number) of \(questions.count)" + (isFollowUp ? " - Follow-up" : "")
    }

    /// Remaining time formatted as `m:ss`.
    var formattedRemainingTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    /// Whether the setup screen should disable Start while preparing to enter the session.
    var isPreparingInterviewStart: Bool {
        isRequestingMicrophonePermission || isGeneratingInterviewQuestions
    }

    // MARK: - Home Actions

    /// Fills the Home text editor with a complete sample job opening.
    func useExampleJobOpening() {
        jobOpening = MockHirelogueData.exampleJobOpening
    }

    /// Extracts a job profile with Foundation Models, falling back to mock data if unavailable.
    func analyzeJobOpening(onComplete: @escaping () -> Void) {
        guard canAnalyze else { return }
        isAnalyzing = true
        analysisProgress = 0
        analysisErrorMessage = nil
        analysisStatusMessage = "Preparing the job opening for analysis."

        let opening = jobOpening
        analysisTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            analysisProgress = 0.25
            analysisStatusMessage = "Extracting the role and seniority."

            do {
                let profile = try await jobAnalysisService.analyze(jobOpening: opening)
                guard !Task.isCancelled else { return }
                analysisProgress = 0.85
                analysisStatusMessage = "Organizing responsibilities, qualifications, and competencies."
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                finishAnalysis(with: profile, onComplete: onComplete)
            } catch {
                guard !Task.isCancelled else { return }
                analysisErrorMessage = error.localizedDescription
                analysisStatusMessage = "Using prototype fallback data because Foundation Models could not complete analysis."
                let fallbackProfile = (try? await fallbackJobAnalysisService.analyze(jobOpening: opening)) ?? MockHirelogueData.jobProfile
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                finishAnalysis(with: fallbackProfile, onComplete: onComplete)
            }
        }
    }

    /// Commits the analyzed profile and lets the root coordinator navigate to setup.
    private func finishAnalysis(with profile: JobProfile, onComplete: @escaping () -> Void) {
        jobProfile = profile
        questions = MockHirelogueData.questions
        completed = false
        analysisProgress = 1
        isAnalyzing = false
        onComplete()
    }

    // MARK: - Setup Actions

    /// Applies edits from the setup sheet while preserving existing values for blank fields.
    func updateProfile(position: String, seniority: String) {
        guard var profile = jobProfile else { return }
        let trimmedPosition = position.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSeniority = seniority.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.position = trimmedPosition.isEmpty ? profile.position : trimmedPosition
        profile.seniority = trimmedSeniority.isEmpty ? profile.seniority : trimmedSeniority
        jobProfile = profile
    }

    /// Replaces the editable profile list sections with non-empty trimmed entries.
    func updateProfileList(_ keyPath: WritableKeyPath<JobProfile, [String]>, items: [String]) {
        guard var profile = jobProfile else { return }
        let trimmedItems = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        profile[keyPath: keyPath] = trimmedItems
        jobProfile = profile
    }

    /// Removes one technical competency from the editable mock profile.
    func removeTechnicalCompetency(_ competency: String) {
        guard var profile = jobProfile else { return }
        profile.technicalCompetencies.removeAll { $0 == competency }
        jobProfile = profile
    }

    /// Removes one behavioral competency from the editable mock profile.
    func removeBehavioralCompetency(_ competency: String) {
        guard var profile = jobProfile else { return }
        profile.behavioralCompetencies.removeAll { $0 == competency }
        jobProfile = profile
    }

    /// Generates the interview question plan from the user-confirmed setup profile and prints it to Xcode's console.
    func generateInterviewQuestionsForCurrentProfile() async -> Bool {
        guard let profile = jobProfile else { return false }

        isGeneratingInterviewQuestions = true
        questionGenerationErrorMessage = nil

        do {
            let generatedQuestions = try await interviewQuestionService.generateQuestions(
                for: profile,
                interviewType: interviewType,
                duration: duration
            )
            guard !generatedQuestions.isEmpty else {
                throw InterviewQuestionGenerationError.emptyQuestionPlan
            }

            questions = generatedQuestions
            printInterviewQuestions(generatedQuestions, source: "Foundation Models")
            isGeneratingInterviewQuestions = false
            return true
        } catch {
            questionGenerationErrorMessage = error.localizedDescription
            let fallbackQuestions = (try? await fallbackInterviewQuestionService.generateQuestions(
                for: profile,
                interviewType: interviewType,
                duration: duration
            )) ?? MockHirelogueData.questions
            questions = fallbackQuestions
            printInterviewQuestions(fallbackQuestions, source: "Prototype fallback")
            isGeneratingInterviewQuestions = false
            return true
        }
    }

    /// Requests both microphone and speech-recognition permissions before entering the voice-session UI.
    func requestInterviewAudioPermissions() async -> Bool {
        isRequestingMicrophonePermission = true
        transcriptionErrorMessage = nil

        let isMicrophoneGranted = await AVAudioApplication.requestRecordPermission()
        guard isMicrophoneGranted else {
            transcriptionErrorMessage = "Microphone access is required to hear your spoken answers."
            isRequestingMicrophonePermission = false
            return false
        }

        let isSpeechRecognitionGranted = await speechTranscriptionService.requestSpeechRecognitionPermission()
        isRequestingMicrophonePermission = false

        if !isSpeechRecognitionGranted {
            transcriptionErrorMessage = "Speech recognition access is required to transcribe your answers."
        }

        return isSpeechRecognitionGranted
    }

    // MARK: - Session Actions

    /// Prints the generated question plan in a readable block for early integration checks.
    private func printInterviewQuestions(_ questions: [InterviewQuestion], source: String) {
        print("\n=== Hirelogue Interview Questions (\(source)) ===")
        for (index, question) in questions.enumerated() {
            print("\(index + 1). [\(question.kind.rawValue.capitalized)] \(question.text)")
            print("   Competency: \(question.competency)")
            if let followUp = question.followUp {
                print("   Follow-up: \(followUp)")
            }
        }
        print("=== End Interview Questions ===\n")
    }

    /// Starts a fresh mock interview and begins the timer-driven phase machine.
    func startInterview() {
        cancelInterviewTasks()
        phase = .speaking
        questionIndex = 0
        isFollowUp = false
        generatedFollowUpQuestion = nil
        followUpGenerationErrorMessage = nil
        feedbackGenerationErrorMessage = nil
        isGeneratingFeedback = false
        answerHistory = []
        feedback = MockHirelogueData.feedback
        pauseCountdown = 3
        secondsRemaining = duration.rawValue * 60
        completed = false
        shouldShowFeedback = false
        resetCurrentAnswerTranscript()
        startRemainingTimeTimer()
        schedulePhaseTransition()
    }

    /// Allows the prototype controls to jump to a specific interview phase.
    func setPhaseForDemo(_ nextPhase: InterviewPhase) {
        phase = nextPhase
        schedulePhaseTransition()
    }

    /// Returns from the paused state to listening, simulating resumed speech.
    func continueSpeaking() {
        phase = .listening
        schedulePhaseTransition()
    }

    /// Lets the candidate submit the current answer without waiting for silence detection.
    func finishCurrentAnswer() {
        guard phase == .listening || phase == .paused else { return }
        phaseTask?.cancel()
        countdownTask?.cancel()
        pauseCountdown = 0

        phaseTask = Task { [weak self] in
            guard let self else { return }
            await stopTranscribingCurrentAnswerSegment()
            guard !Task.isCancelled else { return }
            phase = .processing
            schedulePhaseTransition()
        }
    }

    /// Advances the prototype controls without waiting for the timer sequence.
    func moveToNextQuestionForDemo() {
        isFollowUp = false
        generatedFollowUpQuestion = nil
        questionIndex = (questionIndex + 1) % questions.count
        phase = .speaking
        schedulePhaseTransition()
    }

    /// Ends the current interview early and generates feedback from the answers captured so far.
    func endInterview() {
        cancelInterviewTasks()
        phase = .finished
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            guard let self else { return }
            await generateFinalFeedbackAndShow()
        }
    }

    /// Moves the state machine to its terminal phase.
    func finishInterview() {
        phase = .finished
        schedulePhaseTransition()
    }

    /// Clears session-only state while preserving the analyzed job profile.
    func practiseAgain() {
        completed = false
        shouldShowFeedback = false
        cancelInterviewTasks()
        phase = .speaking
        questionIndex = 0
        isFollowUp = false
        generatedFollowUpQuestion = nil
        feedbackGenerationErrorMessage = nil
        isGeneratingFeedback = false
        answerHistory = []
        feedback = MockHirelogueData.feedback
        resetCurrentAnswerTranscript()
        pauseCountdown = 3
        secondsRemaining = duration.rawValue * 60
    }

    /// Resets all app-base state back to the first Home screen.
    func resetToHome() {
        analysisTask?.cancel()
        cancelInterviewTasks()
        jobOpening = ""
        jobProfile = nil
        interviewType = .mixed
        duration = .ten
        questions = MockHirelogueData.questions
        isAnalyzing = false
        analysisProgress = 0
        analysisStatusMessage = "Identifying the role, qualifications, and interview competencies."
        analysisErrorMessage = nil
        isGeneratingInterviewQuestions = false
        questionGenerationErrorMessage = nil
        transcriptionErrorMessage = nil
        followUpGenerationErrorMessage = nil
        feedbackGenerationErrorMessage = nil
        isGeneratingFeedback = false
        generatedFollowUpQuestion = nil
        answerHistory = []
        feedback = MockHirelogueData.feedback
        resetCurrentAnswerTranscript()
        phase = .speaking
        questionIndex = 0
        isFollowUp = false
        pauseCountdown = 3
        secondsRemaining = InterviewDuration.ten.rawValue * 60
        completed = false
        shouldShowFeedback = false
    }

    // MARK: - Timers and Phase Machine

    /// Counts down the selected duration independently from question phase timing.
    private func startRemainingTimeTimer() {
        remainingTimeTask?.cancel()
        remainingTimeTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if phase == .finished { return }
                secondsRemaining = max(0, secondsRemaining - 1)
                if secondsRemaining == 0 {
                    finishInterview()
                    return
                }
            }
        }
    }

    /// Drives the interview phases: speaking -> listening -> paused warning -> processing.
    private func schedulePhaseTransition() {
        speechSynthesisService.stopSpeaking()
        phaseTask?.cancel()
        countdownTask?.cancel()

        if phase != .listening && phase != .paused {
            Task { [weak self] in
                guard let self else { return }
                await stopTranscribingCurrentAnswerSegment()
            }
        }

        switch phase {
        case .speaking:
            phaseTask = Task { [weak self] in
                guard let self else { return }
                await speechSynthesisService.speak(currentQuestionText)
                guard !Task.isCancelled else { return }
                // Give the audio route a brief moment to settle before switching from speech output to recording.
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                phase = .listening
                schedulePhaseTransition()
            }
        case .listening:
            phaseTask = Task { [weak self] in
                guard let self else { return }
                await startTranscribingCurrentAnswerSegment()
                await monitorForInitialSilence()
            }
        case .paused:
            pauseCountdown = 3
            countdownTask = Task { [weak self] in
                guard let self else { return }
                let warningStartedAt = lastTranscriptActivityDate
                let pausedStartedAt = Date()

                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled, phase == .paused else { return }

                    if lastTranscriptActivityDate > warningStartedAt {
                        phase = .listening
                        schedulePhaseTransition()
                        return
                    }

                    if Date().timeIntervalSince(pausedStartedAt) >= silenceFinalizeInterval {
                        pauseCountdown = 0
                        await stopTranscribingCurrentAnswerSegment()
                        phase = .processing
                        schedulePhaseTransition()
                        return
                    }

                    pauseCountdown = max(0, Int(ceil(silenceFinalizeInterval - Date().timeIntervalSince(pausedStartedAt))))
                }
            }
        case .processing:
            phaseTask = Task { [weak self] in
                guard let self else { return }
                await processCurrentAnswerAndAdvance()
            }
        case .finished:
            remainingTimeTask?.cancel()
            phaseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                guard let self, !Task.isCancelled else { return }
                await generateFinalFeedbackAndShow()
            }
        }
    }

    // MARK: - Speech Transcription

    /// Clears the answer transcript when the interviewer moves to a new question prompt.
    private func resetCurrentAnswerTranscript() {
        currentAnswerTranscriptSegments = []
        currentAnswerTranscript = ""
        bestPartialTranscript = ""
        liveTranscript = ""
        isTranscribing = false
        lastTranscriptActivityDate = Date()
    }

    /// Starts a SpeechAnalyzer capture pass and mirrors partial transcription into the visible session UI.
    private func startTranscribingCurrentAnswerSegment() async {
        guard !isTranscribing else { return }

        transcriptionErrorMessage = nil
        isTranscribing = true
        lastTranscriptActivityDate = Date()

        do {
            try await speechTranscriptionService.startTranscribing { [weak self] (partialTranscript: String) in
                guard let self else { return }
                let didUpdateTranscript = mergePartialTranscript(partialTranscript)

                if didUpdateTranscript {
                    lastTranscriptActivityDate = Date()

                    if phase == .paused {
                        pauseCountdown = 3
                        phase = .listening
                        schedulePhaseTransition()
                    }
                }
            }
        } catch {
            isTranscribing = false
            transcriptionErrorMessage = error.localizedDescription
            print("Hirelogue transcription start error: \(error.localizedDescription)")
        }
    }

    /// Watches for the first silence window while recording remains active.
    private func monitorForInitialSilence() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, phase == .listening else { return }

            if Date().timeIntervalSince(lastTranscriptActivityDate) >= silenceWarningInterval {
                pauseCountdown = Int(silenceFinalizeInterval)
                phase = .paused
                schedulePhaseTransition()
                return
            }
        }
    }

    /// Preserves the best full-session transcript while ignoring empty, shorter, or duplicate recognizer revisions.
    private func mergePartialTranscript(_ partialTranscript: String) -> Bool {
        let cleanedPartial = normalizedTranscript(partialTranscript)
        guard !cleanedPartial.isEmpty else { return false }

        if currentAnswerTranscript.isEmpty {
            currentAnswerTranscript = cleanedPartial
            bestPartialTranscript = cleanedPartial
            liveTranscript = currentAnswerTranscript
            return true
        }

        if cleanedPartial == currentAnswerTranscript || cleanedPartial == bestPartialTranscript {
            return false
        }

        if cleanedPartial.count >= bestPartialTranscript.count && cleanedPartial.hasPrefix(bestPartialTranscript) {
            bestPartialTranscript = cleanedPartial
            currentAnswerTranscript = cleanedPartial
            liveTranscript = currentAnswerTranscript
            return true
        }

        if cleanedPartial.count > currentAnswerTranscript.count && cleanedPartial.hasPrefix(currentAnswerTranscript) {
            currentAnswerTranscript = cleanedPartial
            bestPartialTranscript = cleanedPartial
            liveTranscript = currentAnswerTranscript
            return true
        }

        if currentAnswerTranscript.contains(cleanedPartial) {
            return false
        }

        if cleanedPartial.count > currentAnswerTranscript.count {
            currentAnswerTranscript = cleanedPartial
            bestPartialTranscript = cleanedPartial
            liveTranscript = currentAnswerTranscript
            return true
        }

        return false
    }

    /// Collapses whitespace so transcript comparisons are stable across recognizer updates.
    private func normalizedTranscript(_ transcript: String) -> String {
        transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Stops the current capture pass, preserves the final segment, and prints it for debugging.
    private func stopTranscribingCurrentAnswerSegment() async {
        guard isTranscribing else { return }

        let finalSegment = await speechTranscriptionService.stopTranscribing()
        isTranscribing = false
        _ = mergePartialTranscript(finalSegment)

        guard !currentAnswerTranscript.isEmpty else { return }
    }

    // MARK: - Answer Review and Question Progression

    /// Reviews the finalized transcript and either asks one generated follow-up or advances.
    private func processCurrentAnswerAndAdvance() async {
        let answerTranscript = await finalizedCurrentAnswerTranscript()
        try? await Task.sleep(nanoseconds: 650_000_000)
        guard !Task.isCancelled else { return }

        if isFollowUp {
            print("Hirelogue follow-up answer transcript: \(answerTranscript)")
            recordFollowUpAnswer(answerTranscript)
            moveToNextPrimaryQuestion()
            return
        }

        guard let profile = jobProfile else {
            moveToNextPrimaryQuestion()
            return
        }

        let decision: AnswerFollowUpDecision
        do {
            decision = try await answerFollowUpService.generateFollowUpIfNeeded(
                for: profile,
                question: currentQuestion,
                transcript: answerTranscript,
                interviewType: interviewType
            )
            followUpGenerationErrorMessage = nil
        } catch {
            followUpGenerationErrorMessage = error.localizedDescription
            decision = (try? await fallbackAnswerFollowUpService.generateFollowUpIfNeeded(
                for: profile,
                question: currentQuestion,
                transcript: answerTranscript,
                interviewType: interviewType
            )) ?? .noFollowUp
        }

        printFollowUpDecision(decision, answerTranscript: answerTranscript)
        guard decision.needsFollowUp, let followUpQuestion = decision.question else {
            recordPrimaryAnswer(answerTranscript, followUpQuestion: nil)
            moveToNextPrimaryQuestion()
            return
        }

        recordPrimaryAnswer(answerTranscript, followUpQuestion: followUpQuestion)
        generatedFollowUpQuestion = followUpQuestion
        isFollowUp = true
        resetCurrentAnswerTranscript()
        phase = .speaking
        schedulePhaseTransition()
    }

    /// Stores the primary answer before the transcript buffer is cleared for the next prompt.
    private func recordPrimaryAnswer(_ transcript: String, followUpQuestion: String?) {
        let question = currentQuestion
        let answer = InterviewAnswer(
            id: "answer-\(answerHistory.count + 1)-\(question.id)",
            questionID: question.id,
            questionKind: question.kind,
            competency: question.competency,
            questionText: question.text,
            primaryTranscript: transcript.isEmpty ? "[No transcript captured]" : transcript,
            followUpQuestion: followUpQuestion,
            followUpTranscript: nil
        )
        answerHistory.append(answer)
    }

    /// Completes the latest answer record with the transcript from its generated follow-up.
    private func recordFollowUpAnswer(_ transcript: String) {
        let cleanedTranscript = transcript.isEmpty ? "[No transcript captured]" : transcript
        guard let answerIndex = answerHistory.lastIndex(where: { $0.questionID == currentQuestion.id && $0.followUpTranscript == nil }) else {
            recordPrimaryAnswer("[No primary transcript captured]", followUpQuestion: currentQuestionText)
            recordFollowUpAnswer(cleanedTranscript)
            return
        }

        let existingAnswer = answerHistory[answerIndex]
        answerHistory[answerIndex] = InterviewAnswer(
            id: existingAnswer.id,
            questionID: existingAnswer.questionID,
            questionKind: existingAnswer.questionKind,
            competency: existingAnswer.competency,
            questionText: existingAnswer.questionText,
            primaryTranscript: existingAnswer.primaryTranscript,
            followUpQuestion: existingAnswer.followUpQuestion,
            followUpTranscript: cleanedTranscript
        )
    }

    /// Returns the latest answer text after ensuring active transcription has stopped.
    private func finalizedCurrentAnswerTranscript() async -> String {
        await stopTranscribingCurrentAnswerSegment()
        let transcript = normalizedTranscript(currentAnswerTranscript)
        return transcript
    }

    /// Prints the follow-up decision so generated interviewer behavior is visible during development.
    private func printFollowUpDecision(_ decision: AnswerFollowUpDecision, answerTranscript: String) {
        print("\n=== Hirelogue Follow-Up Decision ===")
        print("Question: \(currentQuestion.text)")
        print("Transcript sent to model:")
        print(answerTranscript.isEmpty ? "[No transcript captured]" : answerTranscript)
        print("Follow-up needed: \(decision.needsFollowUp)")
        print("Reason: \(decision.reason)")
        if let question = decision.question {
            print("Follow-up question: \(question)")
        }
        print("=== End Follow-Up Decision ===\n")
    }

    /// Generates final feedback from bounded answer history, then allows navigation to the feedback screen.
    private func generateFinalFeedbackAndShow() async {
        guard let profile = jobProfile else {
            completed = true
            shouldShowFeedback = true
            return
        }

        isGeneratingFeedback = true
        feedbackGenerationErrorMessage = nil

        do {
            feedback = try await interviewFeedbackService.generateFeedback(
                for: profile,
                questions: questions,
                answers: answerHistory,
                interviewType: interviewType,
                duration: duration
            )
        } catch {
            feedbackGenerationErrorMessage = error.localizedDescription
            feedback = (try? await fallbackInterviewFeedbackService.generateFeedback(
                for: profile,
                questions: questions,
                answers: answerHistory,
                interviewType: interviewType,
                duration: duration
            )) ?? MockHirelogueData.feedback
        }

        guard !Task.isCancelled else { return }
        printFinalFeedbackSummary()
        isGeneratingFeedback = false
        completed = true
        shouldShowFeedback = true
    }

    /// Prints a compact feedback-generation summary for development validation.
    private func printFinalFeedbackSummary() {
        print("\n=== Hirelogue Final Feedback ===")
        print("Captured answer turns: \(answerHistory.count)")
        if let feedbackGenerationErrorMessage {
            print("Feedback fallback reason: \(feedbackGenerationErrorMessage)")
        }
        print("Summary: \(feedback.summary)")
        print("=== End Final Feedback ===\n")
    }

    /// Advances to the next primary question, clearing dynamic follow-up and transcript state.
    private func moveToNextPrimaryQuestion() {
        isFollowUp = false
        generatedFollowUpQuestion = nil
        resetCurrentAnswerTranscript()

        if questionIndex >= questions.count - 1 {
            phase = .finished
        } else {
            questionIndex += 1
            phase = .speaking
        }
        schedulePhaseTransition()
    }

    /// Stops all active interview timers, speech, and transcription so stale tasks cannot mutate a new session.
    private func cancelInterviewTasks() {
        feedbackTask?.cancel()
        speechSynthesisService.stopSpeaking()
        Task { [weak self] in
            guard let self else { return }
            await stopTranscribingCurrentAnswerSegment()
        }
        phaseTask?.cancel()
        countdownTask?.cancel()
        remainingTimeTask?.cancel()
        phaseTask = nil
        countdownTask = nil
        remainingTimeTask = nil
    }
}
