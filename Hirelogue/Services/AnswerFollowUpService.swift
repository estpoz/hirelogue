import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Follow-Up Decision Model

/// Result of reviewing one transcribed answer after a primary interview question.
struct AnswerFollowUpDecision: Equatable {
    let needsFollowUp: Bool
    let reason: String
    let question: String?

    static let noFollowUp = AnswerFollowUpDecision(
        needsFollowUp: false,
        reason: "The answer is clear enough to continue.",
        question: nil
    )
}

// MARK: - Service Contract

/// Reviews a candidate transcript and decides whether the interviewer should ask one targeted follow-up.
protocol AnswerFollowUpService {
    func generateFollowUpIfNeeded(
        for profile: JobProfile,
        question: InterviewQuestion,
        transcript: String,
        interviewType: InterviewType
    ) async throws -> AnswerFollowUpDecision
}

// MARK: - Foundation Models Follow-Up Reviewer

/// Uses Apple's on-device Foundation Models framework to decide whether an answer needs one follow-up question.
struct FoundationModelAnswerFollowUpService: AnswerFollowUpService {
    nonisolated init() {}

    func generateFollowUpIfNeeded(
        for profile: JobProfile,
        question: InterviewQuestion,
        transcript: String,
        interviewType: InterviewType
    ) async throws -> AnswerFollowUpDecision {
#if canImport(FoundationModels)
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            return AnswerFollowUpDecision(
                needsFollowUp: true,
                reason: "The candidate did not provide enough answer content to evaluate.",
                question: "Could you share a specific example or more detail about your answer?"
            )
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AnswerFollowUpError.foundationModelUnavailable(model.availability.availabilityDescription)
        }

        // Instructions keep the model in interviewer mode and bound it to one follow-up at most.
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are an interviewer in an interview practice app.
            Review the candidate's transcribed answer and decide if one follow-up question is needed.
            The transcript may contain speech-recognition mistakes, so judge the answer's likely intent and completeness rather than isolated odd words.
            Ask a follow-up only when it would materially improve the answer evaluation.
            Do not score the answer, give feedback, or ask more than one follow-up.
            """
        )

        let prompt = """
        Decide whether this candidate answer needs one follow-up question.

        Job profile:
        - Position: \(profile.position)
        - Seniority: \(profile.seniority)
        - Responsibilities: \(profile.responsibilities.joined(separator: "; "))
        - Required qualifications: \(profile.requiredQualifications.joined(separator: "; "))
        - Technical competencies: \(profile.technicalCompetencies.joined(separator: "; "))
        - Behavioral competencies: \(profile.behavioralCompetencies.joined(separator: "; "))

        Interview context:
        - Type: \(interviewType.rawValue)
        - Original question kind: \(question.kind.rawValue)
        - Original question: \(question.text)
        - Competency being assessed: \(question.competency)

        Candidate transcript:
        \(cleanedTranscript)

        Decision rules:
        - Return needsFollowUp as true only if the answer is vague, incomplete, missing concrete evidence, missing STAR details, technically unclear, or avoids the competency being assessed.
        - Do not ask a follow-up only because one word or phrase appears mistranscribed.
        - Return needsFollowUp as false if the answer is already specific enough to continue.
        - If needsFollowUp is true, write one concise interviewer follow-up question.
        - The follow-up must be answer-specific and should not repeat the original question.
        - If needsFollowUp is false, leave question empty.
        """

        let response = try await session.respond(
            to: prompt,
            generating: GeneratedFollowUpDecision.self
        )
        return response.content.answerFollowUpDecision
#else
        throw AnswerFollowUpError.foundationModelsNotLinked
#endif
    }
}

// MARK: - Prototype Fallback

/// Conservative fallback: continue to the next primary question when AI review is unavailable.
struct MockAnswerFollowUpService: AnswerFollowUpService {
    nonisolated init() {}

    func generateFollowUpIfNeeded(
        for profile: JobProfile,
        question: InterviewQuestion,
        transcript: String,
        interviewType: InterviewType
    ) async throws -> AnswerFollowUpDecision {
        AnswerFollowUpDecision.noFollowUp
    }
}

// MARK: - Follow-Up Errors

enum AnswerFollowUpError: LocalizedError {
    case foundationModelsNotLinked
    case foundationModelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .foundationModelsNotLinked:
            return "Foundation Models is not available in this build."
        case .foundationModelUnavailable(let reason):
            return "Foundation Models is unavailable: \(reason)."
        }
    }
}

#if canImport(FoundationModels)

// MARK: - Guided Generation Schema

@Generable(description: "Decision about whether a candidate answer needs one follow-up question")
private struct GeneratedFollowUpDecision {
    @Guide(description: "True only when the candidate answer needs clarification, detail, evidence, or deeper probing")
    var needsFollowUp: Bool

    @Guide(description: "Brief interviewer-facing reason for the decision")
    var reason: String

    @Guide(description: "One concise follow-up question, or an empty string when no follow-up is needed")
    var question: String

    /// Normalizes model output into the app's follow-up decision model.
    var answerFollowUpDecision: AnswerFollowUpDecision {
        let cleanedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldAskFollowUp = needsFollowUp && !cleanedQuestion.isEmpty

        return AnswerFollowUpDecision(
            needsFollowUp: shouldAskFollowUp,
            reason: cleanedReason.isEmpty ? "No reason returned." : cleanedReason,
            question: shouldAskFollowUp ? cleanedQuestion : nil
        )
    }
}

// MARK: - Availability Display

private extension SystemLanguageModel.Availability {
    var availabilityDescription: String {
        switch self {
        case .available:
            return "available"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is not enabled"
        case .unavailable(.deviceNotEligible):
            return "this device does not support Apple Intelligence"
        case .unavailable(.modelNotReady):
            return "the on-device model is not ready"
        case .unavailable(let reason):
            return String(describing: reason)
        }
    }
}
#endif
