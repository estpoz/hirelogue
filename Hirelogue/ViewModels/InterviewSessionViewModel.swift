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
    var isRequestingMicrophonePermission = false

    // MARK: - Interview Session State

    var phase: InterviewPhase = .speaking
    var questionIndex = 0
    var isFollowUp = false
    var pauseCountdown = 3
    var secondsRemaining = InterviewDuration.ten.rawValue * 60
    var completed = false
    var shouldShowFeedback = false

    // MARK: - Static Fixtures

    let questions = MockHirelogueData.questions
    let feedback = MockHirelogueData.feedback

    // MARK: - Internal Tasks

    /// Unstructured tasks drive short prototype delays and must be cancelled
    /// when the user restarts, exits, or jumps between demo states.
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var phaseTask: Task<Void, Never>?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var remainingTimeTask: Task<Void, Never>?

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

    // MARK: - Home Actions

    /// Fills the Home text editor with a complete sample job opening.
    func useExampleJobOpening() {
        jobOpening = MockHirelogueData.exampleJobOpening
    }

    /// Simulates analysis progress, then installs the mock job profile.
    func analyzeJobOpening(onComplete: @escaping () -> Void) {
        guard canAnalyze else { return }
        analysisTask?.cancel()
        isAnalyzing = true
        analysisProgress = 0

        analysisTask = Task { [weak self] in
            guard let self else { return }
            let steps: [(UInt64, Double)] = [
                (400_000_000, 0.25),
                (500_000_000, 0.55),
                (500_000_000, 0.80),
                (500_000_000, 1.00)
            ]

            for step in steps {
                try? await Task.sleep(nanoseconds: step.0)
                guard !Task.isCancelled else { return }
                analysisProgress = step.1
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            jobProfile = MockHirelogueData.jobProfile
            completed = false
            isAnalyzing = false
            onComplete()
        }
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

    /// Requests system microphone permission before entering the voice-session UI.
    func requestMicrophonePermission() async -> Bool {
        isRequestingMicrophonePermission = true
        let isGranted = await AVAudioApplication.requestRecordPermission()
        isRequestingMicrophonePermission = false
        return isGranted
    }

    // MARK: - Session Actions

    /// Starts a fresh mock interview and begins the timer-driven phase machine.
    func startInterview() {
        cancelInterviewTasks()
        phase = .speaking
        questionIndex = 0
        isFollowUp = false
        pauseCountdown = 3
        secondsRemaining = duration.rawValue * 60
        completed = false
        shouldShowFeedback = false
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

    /// Advances the prototype controls without waiting for the timer sequence.
    func moveToNextQuestionForDemo() {
        isFollowUp = false
        questionIndex = (questionIndex + 1) % questions.count
        phase = .speaking
        schedulePhaseTransition()
    }

    /// Ends the current mock interview and asks navigation to show feedback.
    func endInterview() {
        completed = true
        shouldShowFeedback = true
        cancelInterviewTasks()
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
        isAnalyzing = false
        analysisProgress = 0
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

    /// Drives the scripted mock interview: speaking -> listening -> paused -> processing.
    private func schedulePhaseTransition() {
        phaseTask?.cancel()
        countdownTask?.cancel()

        switch phase {
        case .speaking:
            phaseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                guard let self, !Task.isCancelled else { return }
                phase = .listening
                schedulePhaseTransition()
            }
        case .listening:
            phaseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_500_000_000)
                guard let self, !Task.isCancelled else { return }
                pauseCountdown = 3
                phase = .paused
                schedulePhaseTransition()
            }
        case .paused:
            pauseCountdown = 3
            countdownTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self, !Task.isCancelled else { return }
                    if pauseCountdown <= 1 {
                        pauseCountdown = 0
                        phase = .processing
                        schedulePhaseTransition()
                        return
                    }
                    pauseCountdown -= 1
                }
            }
        case .processing:
            phaseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard let self, !Task.isCancelled else { return }
                advanceQuestion()
            }
        case .finished:
            remainingTimeTask?.cancel()
            phaseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                guard let self, !Task.isCancelled else { return }
                completed = true
                shouldShowFeedback = true
            }
        }
    }

    /// Chooses a follow-up when available, otherwise advances to the next question.
    private func advanceQuestion() {
        if !isFollowUp, currentQuestion.followUp != nil {
            isFollowUp = true
            phase = .speaking
            schedulePhaseTransition()
            return
        }

        isFollowUp = false
        if questionIndex >= questions.count - 1 {
            phase = .finished
        } else {
            questionIndex += 1
            phase = .speaking
        }
        schedulePhaseTransition()
    }

    /// Stops all active interview timers so stale tasks cannot mutate a new session.
    private func cancelInterviewTasks() {
        phaseTask?.cancel()
        countdownTask?.cancel()
        remainingTimeTask?.cancel()
        phaseTask = nil
        countdownTask = nil
        remainingTimeTask = nil
    }
}
