import AVFAudio
import Foundation
import Observation

@MainActor
@Observable
final class InterviewSessionViewModel {
    var jobOpening = ""
    var jobProfile: JobProfile?
    var interviewType: InterviewType = .mixed
    var duration: InterviewDuration = .ten
    var isAnalyzing = false
    var analysisProgress = 0.0
    var phase: InterviewPhase = .speaking
    var questionIndex = 0
    var isFollowUp = false
    var pauseCountdown = 3
    var secondsRemaining = InterviewDuration.ten.rawValue * 60
    var completed = false
    var shouldShowFeedback = false
    var isRequestingMicrophonePermission = false

    let questions = MockHirelogueData.questions
    let feedback = MockHirelogueData.feedback

    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var phaseTask: Task<Void, Never>?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var remainingTimeTask: Task<Void, Never>?

    var canAnalyze: Bool {
        !jobOpening.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    var currentQuestion: InterviewQuestion {
        questions[min(questionIndex, questions.count - 1)]
    }

    var currentQuestionText: String {
        if isFollowUp, let followUp = currentQuestion.followUp {
            return followUp
        }
        return currentQuestion.text
    }

    var questionProgressTitle: String {
        let number = min(questionIndex + 1, questions.count)
        return "Question \(number) of \(questions.count)" + (isFollowUp ? " - Follow-up" : "")
    }

    var formattedRemainingTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    func useExampleJobOpening() {
        jobOpening = MockHirelogueData.exampleJobOpening
    }

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

    func updateProfile(position: String, seniority: String) {
        guard var profile = jobProfile else { return }
        let trimmedPosition = position.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSeniority = seniority.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.position = trimmedPosition.isEmpty ? profile.position : trimmedPosition
        profile.seniority = trimmedSeniority.isEmpty ? profile.seniority : trimmedSeniority
        jobProfile = profile
    }

    func removeTechnicalCompetency(_ competency: String) {
        guard var profile = jobProfile else { return }
        profile.technicalCompetencies.removeAll { $0 == competency }
        jobProfile = profile
    }

    func removeBehavioralCompetency(_ competency: String) {
        guard var profile = jobProfile else { return }
        profile.behavioralCompetencies.removeAll { $0 == competency }
        jobProfile = profile
    }

    func requestMicrophonePermission() async -> Bool {
        isRequestingMicrophonePermission = true
        let isGranted = await AVAudioApplication.requestRecordPermission()
        isRequestingMicrophonePermission = false
        return isGranted
    }

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

    func setPhaseForDemo(_ nextPhase: InterviewPhase) {
        phase = nextPhase
        schedulePhaseTransition()
    }

    func continueSpeaking() {
        phase = .listening
        schedulePhaseTransition()
    }

    func moveToNextQuestionForDemo() {
        isFollowUp = false
        questionIndex = (questionIndex + 1) % questions.count
        phase = .speaking
        schedulePhaseTransition()
    }

    func endInterview() {
        completed = true
        shouldShowFeedback = true
        cancelInterviewTasks()
    }

    func finishInterview() {
        phase = .finished
        schedulePhaseTransition()
    }

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

    private func cancelInterviewTasks() {
        phaseTask?.cancel()
        countdownTask?.cancel()
        remainingTimeTask?.cancel()
        phaseTask = nil
        countdownTask = nil
        remainingTimeTask = nil
    }
}
