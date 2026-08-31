import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Service Contract

/// Generates structured post-interview feedback from the confirmed role and captured answer transcripts.
protocol InterviewFeedbackService {
    func generateFeedback(
        for profile: JobProfile,
        questions: [InterviewQuestion],
        answers: [InterviewAnswer],
        interviewType: InterviewType,
        duration: InterviewDuration
    ) async throws -> InterviewFeedback
}

// MARK: - Foundation Models Feedback Generator

/// Uses Apple's on-device Foundation Models framework to produce the final structured feedback screen payload.
struct FoundationModelInterviewFeedbackService: InterviewFeedbackService {
    nonisolated init() {}

    func generateFeedback(
        for profile: JobProfile,
        questions: [InterviewQuestion],
        answers: [InterviewAnswer],
        interviewType: InterviewType,
        duration: InterviewDuration
    ) async throws -> InterviewFeedback {
#if canImport(FoundationModels)
        guard !answers.isEmpty else {
            throw InterviewFeedbackGenerationError.emptyAnswerHistory
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw InterviewFeedbackGenerationError.foundationModelUnavailable(model.availability.availabilityDescription)
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You create evidence-based English practice interview feedback.
            Use only the supplied job profile, interview questions, and transcripts.
            Do not predict hiring outcomes, evaluate accent, infer emotion, use resume details, or add external company research.
            Keep every field concise and actionable for one mobile feedback screen.
            """
        )

        let prompt = """
        Generate structured post-interview feedback for this practice session.

        Job profile:
        - Position: \(profile.position)
        - Seniority: \(profile.seniority)
        - Responsibilities: \(boundedJoined(profile.responsibilities, limit: 5))
        - Required qualifications: \(boundedJoined(profile.requiredQualifications, limit: 5))
        - Preferred qualifications: \(boundedJoined(profile.preferredQualifications, limit: 4))
        - Technical competencies: \(boundedJoined(profile.technicalCompetencies, limit: 8))
        - Behavioral competencies: \(boundedJoined(profile.behavioralCompetencies, limit: 6))

        Interview settings:
        - Type: \(interviewType.rawValue)
        - Duration: \(duration.title)
        - Primary questions asked: \(questions.count)

        Candidate answer evidence:
        \(answerEvidence(from: answers))

        Output requirements:
        - Summary: 2 to 3 sentences, practice-focused, no hiring prediction.
        - Competencies: include assessed technical and behavioral competencies from the profile or questions only.
        - Strengths: 2 to 3 items with transcript-grounded details.
        - Improvements: 2 to 3 items with specific next-action details.
        - STAR: evaluate one behavioral answer when available; otherwise mark missing parts as needs improvement.
        - Technical reasoning: 2 to 3 concise notes about clarity, trade-offs, assumptions, or depth.
        - Suggested improvement: rewrite one selected answer as a stronger example formulation.
        - Recommendations: exactly 3 practice areas.
        """

        let response = try await session.respond(
            to: prompt,
            generating: GeneratedInterviewFeedback.self
        )
        return response.content.interviewFeedback
#else
        throw InterviewFeedbackGenerationError.foundationModelsNotLinked
#endif
    }

    private func boundedJoined(_ items: [String], limit: Int) -> String {
        let cleanedItems = items
            .prefix(limit)
            .map { compactText($0, characterLimit: 140) }
        return cleanedItems.isEmpty ? "Not specified" : cleanedItems.joined(separator: "; ")
    }

    private func answerEvidence(from answers: [InterviewAnswer]) -> String {
        answers.prefix(5).enumerated().map { index, answer in
            var lines = [
                "Turn \(index + 1):",
                "- Kind: \(answer.questionKind.rawValue)",
                "- Competency: \(answer.competency)",
                "- Question: \(compactText(answer.questionText, characterLimit: 260))",
                "- Answer: \(compactText(answer.primaryTranscript, characterLimit: 900))"
            ]

            if let followUpQuestion = answer.followUpQuestion, let followUpTranscript = answer.followUpTranscript {
                lines.append("- Follow-up question: \(compactText(followUpQuestion, characterLimit: 240))")
                lines.append("- Follow-up answer: \(compactText(followUpTranscript, characterLimit: 500))")
            }

            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private func compactText(_ text: String, characterLimit: Int) -> String {
        let cleaned = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard cleaned.count > characterLimit else {
            return cleaned.isEmpty ? "[No transcript captured]" : cleaned
        }

        let endIndex = cleaned.index(cleaned.startIndex, offsetBy: characterLimit)
        return String(cleaned[..<endIndex]) + "..."
    }
}

// MARK: - Prototype Fallback

/// Deterministic fallback that keeps the final screen available when Foundation Models feedback generation fails.
struct MockInterviewFeedbackService: InterviewFeedbackService {
    nonisolated init() {}

    func generateFeedback(
        for profile: JobProfile,
        questions: [InterviewQuestion],
        answers: [InterviewAnswer],
        interviewType: InterviewType,
        duration: InterviewDuration
    ) async throws -> InterviewFeedback {
        MockHirelogueData.feedback
    }
}

// MARK: - Feedback Errors

enum InterviewFeedbackGenerationError: LocalizedError {
    case foundationModelsNotLinked
    case foundationModelUnavailable(String)
    case emptyAnswerHistory

    var errorDescription: String? {
        switch self {
        case .foundationModelsNotLinked:
            return "Foundation Models is not available in this build."
        case .foundationModelUnavailable(let reason):
            return "Foundation Models is unavailable: \(reason)."
        case .emptyAnswerHistory:
            return "No interview answers were captured for feedback generation."
        }
    }
}

#if canImport(FoundationModels)

// MARK: - Guided Generation Schema

@Generable(description: "Structured final feedback for one interview practice session")
private struct GeneratedInterviewFeedback {
    @Guide(description: "Two to three concise sentences summarizing the candidate's practice performance")
    var summary: String

    @Guide(description: "Technical competencies assessed, using short notes such as Clearly explained, Partly explained, or Not covered", .maximumCount(6))
    var technicalCompetencies: [GeneratedCompetencyAssessment]

    @Guide(description: "Behavioral competencies assessed, using short notes such as Clearly explained, Partly explained, or Not covered", .maximumCount(6))
    var behavioralCompetencies: [GeneratedCompetencyAssessment]

    @Guide(description: "Two or three strengths grounded in the transcript", .minimumCount(2), .maximumCount(3))
    var strengths: [GeneratedFeedbackPoint]

    @Guide(description: "Two or three improvement areas grounded in the transcript", .minimumCount(2), .maximumCount(3))
    var improvements: [GeneratedFeedbackPoint]

    @Guide(description: "Question text or short label for the behavioral answer used for STAR review")
    var starQuestion: String

    @Guide(description: "STAR assessment entries for Situation, Task, Action, and Result", .minimumCount(4), .maximumCount(4))
    var starAssessments: [GeneratedSTARAssessment]

    @Guide(description: "Two or three complete sentence notes on technical reasoning quality. Each item must contain words, not punctuation or fragments.", .minimumCount(2), .maximumCount(3))
    var technicalReasoning: [String]

    @Guide(description: "Question text or short label for the answer being improved")
    var improvedAnswerQuestion: String

    @Guide(description: "One stronger example answer formulation based only on the supplied transcript and job profile")
    var improvedAnswer: String

    @Guide(description: "Exactly three recommended practice areas", .minimumCount(3), .maximumCount(3))
    var recommendations: [String]

    var interviewFeedback: InterviewFeedback {
        InterviewFeedback(
            summary: clean(summary, fallback: "Your interview answers were reviewed against the role requirements. Use the notes below as practice feedback, not as a hiring prediction."),
            technicalCompetencies: technicalCompetencies.compactMap(\.competencyAssessment),
            behavioralCompetencies: behavioralCompetencies.compactMap(\.competencyAssessment),
            strengths: strengths.compactMap(\.feedbackPoint),
            improvements: improvements.compactMap(\.feedbackPoint),
            starQuestion: clean(starQuestion, fallback: "Behavioral answer"),
            starAssessments: normalizedSTARAssessments,
            technicalReasoning: cleanedList(technicalReasoning, fallback: ["Add more detail about constraints, trade-offs, and outcomes in technical answers."]),
            improvedAnswerQuestion: clean(improvedAnswerQuestion, fallback: "Selected answer"),
            improvedAnswer: clean(improvedAnswer, fallback: "A stronger answer should name the context, explain the decision, describe the action taken, and close with the result."),
            recommendations: Array(cleanedList(recommendations, fallback: MockHirelogueData.feedback.recommendations).prefix(3))
        )
    }

    private var normalizedSTARAssessments: [STARAssessment] {
        let generated = starAssessments.compactMap(\.starAssessment)
        guard generated.count == 4 else {
            return MockHirelogueData.feedback.starAssessments
        }
        return generated
    }

    private func cleanedList(_ items: [String], fallback: [String]) -> [String] {
        let cleanedItems = items
            .compactMap(validGeneratedText)
        return cleanedItems.isEmpty ? fallback : cleanedItems
    }

    private func clean(_ value: String, fallback: String) -> String {
        validGeneratedText(value) ?? fallback
    }

}

@Generable(description: "A competency assessment note")
private struct GeneratedCompetencyAssessment {
    @Guide(description: "Competency name")
    var name: String

    @Guide(description: "Short assessment note")
    var note: String

    var competencyAssessment: CompetencyAssessment? {
        guard let cleanedName = validGeneratedText(name) else { return nil }
        let cleanedNote = validGeneratedText(note) ?? "Partly explained"
        return CompetencyAssessment(name: cleanedName, note: cleanedNote)
    }
}

@Generable(description: "A concise feedback point with optional supporting detail")
private struct GeneratedFeedbackPoint {
    @Guide(description: "Short feedback point")
    var point: String

    @Guide(description: "Specific supporting detail or example from the transcript")
    var detail: String

    var feedbackPoint: FeedbackPoint? {
        guard let cleanedPoint = validGeneratedText(point) else { return nil }
        let cleanedDetail = validGeneratedText(detail)
        return FeedbackPoint(point: cleanedPoint, detail: cleanedDetail)
    }
}

@Generable(description: "One STAR structure assessment entry")
private struct GeneratedSTARAssessment {
    @Guide(description: "One of Situation, Task, Action, or Result")
    var label: String

    @Guide(description: "Whether this STAR element is present in the answer")
    var present: Bool

    @Guide(description: "Brief note explaining the assessment")
    var note: String

    var starAssessment: STARAssessment? {
        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedLabel.isEmpty else { return nil }
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return STARAssessment(label: cleanedLabel, present: present, note: cleanedNote.isEmpty ? "No detail returned." : cleanedNote)
    }
}

// MARK: - Generated Text Cleanup

private func validGeneratedText(_ value: String) -> String? {
    let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
    return cleaned
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
