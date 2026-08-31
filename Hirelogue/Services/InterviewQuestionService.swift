import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Service Contract

/// Generates a bounded interview question plan from the confirmed job profile.
protocol InterviewQuestionService {
    func generateQuestions(
        for profile: JobProfile,
        interviewType: InterviewType,
        duration: InterviewDuration
    ) async throws -> [InterviewQuestion]
}

// MARK: - Foundation Models Generator

/// Uses Apple's on-device Foundation Models framework to create role-specific interview questions.
struct FoundationModelInterviewQuestionService: InterviewQuestionService {
    nonisolated init() {}

    func generateQuestions(
        for profile: JobProfile,
        interviewType: InterviewType,
        duration: InterviewDuration
    ) async throws -> [InterviewQuestion] {
#if canImport(FoundationModels)
        // Apple Intelligence can be unavailable on unsupported devices, disabled systems, or while assets are still preparing.
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw InterviewQuestionGenerationError.foundationModelUnavailable(model.availability.availabilityDescription)
        }

        // Instructions define durable interviewer behavior; the edited job profile stays in the lower-priority prompt.
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You create English interview questions for an interview practice app.
            Generate questions only from the confirmed job profile supplied by the app.
            Keep the interview bounded, practical, and relevant to the selected interview type.
            """
        )

        let prompt = """
        Generate an interview question plan for this confirmed job profile.

        Interview settings:
        - Type: \(interviewType.rawValue)
        - Duration: \(duration.title)
        - Maximum primary questions: 5
        - Follow-up questions are generated later from transcribed answers, not during setup

        Job profile:
        - Position: \(profile.position)
        - Seniority: \(profile.seniority)
        - Responsibilities: \(profile.responsibilities.joined(separator: "; "))
        - Required qualifications: \(profile.requiredQualifications.joined(separator: "; "))
        - Preferred qualifications: \(profile.preferredQualifications.joined(separator: "; "))
        - Technical competencies: \(profile.technicalCompetencies.joined(separator: "; "))
        - Behavioral competencies: \(profile.behavioralCompetencies.joined(separator: "; "))

        Requirements:
        - Return exactly \(questionCount(for: duration)) primary questions.
        - Use the selected interview type. Mixed should include both technical and behavioral questions.
        - Each question must assess one named competency from the profile when possible.
        - Generate primary questions only. Do not generate follow-up questions yet.
        - Do not ask about resumes, external company research, video, emotions, accent, or hiring prediction.
        """

        // Guided generation returns a typed question plan, avoiding manual JSON or string parsing.
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedInterviewQuestionPlan.self
        )
        return response.content.interviewQuestions
#else
        throw InterviewQuestionGenerationError.foundationModelsNotLinked
#endif
    }

    private func questionCount(for duration: InterviewDuration) -> Int {
        switch duration {
        case .five:
            return 3
        case .ten:
            return 4
        case .fifteen:
            return 5
        }
    }
}

// MARK: - Prototype Fallback

/// Deterministic fallback that preserves the prototype flow when question generation fails.
struct MockInterviewQuestionService: InterviewQuestionService {
    nonisolated init() {}

    func generateQuestions(
        for profile: JobProfile,
        interviewType: InterviewType,
        duration: InterviewDuration
    ) async throws -> [InterviewQuestion] {
        MockHirelogueData.questions.map { question in
            InterviewQuestion(
                id: question.id,
                kind: question.kind,
                text: question.text,
                competency: question.competency,
                followUp: nil
            )
        }
    }
}

// MARK: - Generation Errors

enum InterviewQuestionGenerationError: LocalizedError {
    case foundationModelsNotLinked
    case foundationModelUnavailable(String)
    case emptyQuestionPlan

    var errorDescription: String? {
        switch self {
        case .foundationModelsNotLinked:
            return "Foundation Models is not available in this build."
        case .foundationModelUnavailable(let reason):
            return "Foundation Models is unavailable: \(reason)."
        case .emptyQuestionPlan:
            return "Foundation Models did not return any interview questions."
        }
    }
}

#if canImport(FoundationModels)

// MARK: - Guided Generation Schema

@Generable(description: "A short interview question plan")
private struct GeneratedInterviewQuestionPlan {
    @Guide(description: "Three to five primary interview questions", .minimumCount(3), .maximumCount(5))
    var questions: [GeneratedInterviewQuestion]

    /// Converts generated output into the app's existing question model.
    var interviewQuestions: [InterviewQuestion] {
        let cleanedQuestions = questions.enumerated().compactMap { index, question in
            question.interviewQuestion(index: index)
        }

        return cleanedQuestions.isEmpty ? [] : cleanedQuestions
    }
}

@Generable(description: "One primary interview question")
private struct GeneratedInterviewQuestion {
    @Guide(description: "Either technical or behavioral")
    var kind: String

    @Guide(description: "Primary interview question text")
    var text: String

    @Guide(description: "Main competency assessed by this question")
    var competency: String

    func interviewQuestion(index: Int) -> InterviewQuestion? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return nil }

        let cleanedCompetency = competency.trimmingCharacters(in: .whitespacesAndNewlines)

        return InterviewQuestion(
            id: "generated-q\(index + 1)",
            kind: questionKind,
            text: cleanedText,
            competency: cleanedCompetency.isEmpty ? "Role fit" : cleanedCompetency,
            followUp: nil
        )
    }

    private var questionKind: InterviewQuestion.Kind {
        kind.localizedCaseInsensitiveContains("behavior") ? .behavioral : .technical
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
