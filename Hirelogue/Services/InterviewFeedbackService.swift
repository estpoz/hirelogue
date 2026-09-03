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
            Treat transcripts as speech-recognition output that may contain occasional incorrect words.
            Assess the exact technical and behavioral competency names supplied in the job profile. Do not invent, rename, or duplicate competencies across sections.
            Treat competency assessments as the source of truth for all later feedback sections.
            Do not write a positive technical reasoning note for a competency marked Not covered.
            Mention Not covered competencies only as gaps or recommended practice areas.
            For STAR assessment, the present value must agree with the note. If the note says the element is missing, unclear, not specific, or not provided, present must be false.
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
        - Technical competencies: assess only these exact names: \(boundedJoined(profile.technicalCompetencies, limit: 8)).
        - Behavioral competencies: assess only these exact names: \(boundedJoined(profile.behavioralCompetencies, limit: 6)).
        - Competency notes must use one of: Clearly explained, Partly explained, Not covered.
        - Strengths: 2 to 3 items with transcript-grounded details.
        - Improvements: 2 to 3 items with specific next-action details.
        - Do not penalize wording, grammar, or isolated strange terms that could be speech-recognition artifacts.
        - STAR: return exactly Situation, Task, Action, and Result. Mark present false when the transcript lacks a specific element.
        - Technical reasoning: 2 to 3 concise notes about clarity, trade-offs, assumptions, or depth. Each positive claim must be supported by submitted answer evidence and must not contradict the competency notes.
        - Suggested improvement: rewrite one selected answer as a stronger example formulation.
        - Recommendations: exactly 3 practice areas.
        """

        let response = try await session.respond(
            to: prompt,
            generating: GeneratedInterviewFeedback.self
        )
        return response.content.interviewFeedback(for: profile, answers: answers)
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

/// Deterministic fallback that avoids showing mock examples as if they came from the user's answers.
struct MockInterviewFeedbackService: InterviewFeedbackService {
    nonisolated init() {}

    func generateFeedback(
        for profile: JobProfile,
        questions: [InterviewQuestion],
        answers: [InterviewAnswer],
        interviewType: InterviewType,
        duration: InterviewDuration
    ) async throws -> InterviewFeedback {
        guard !answers.isEmpty else {
            throw InterviewFeedbackGenerationError.emptyAnswerHistory
        }

        return InterviewFeedback(
            summary: "No generated feedback yet because Foundation Models could not complete the review for this session.",
            technicalCompetencies: [],
            behavioralCompetencies: [],
            strengths: [],
            improvements: [],
            starQuestion: "",
            starAssessments: [],
            technicalReasoning: [],
            improvedAnswerQuestion: "",
            improvedAnswer: "",
            recommendations: []
        )
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

    func interviewFeedback(for profile: JobProfile, answers: [InterviewAnswer]) -> InterviewFeedback {
        let repairedTechnicalCompetencies = repairedCompetencies(
            generated: technicalCompetencies,
            allowedNames: profile.technicalCompetencies
        )
        let repairedBehavioralCompetencies = repairedCompetencies(
            generated: behavioralCompetencies,
            allowedNames: profile.behavioralCompetencies
        )
        let repairedTechnicalReasoning = consistencyCheckedTechnicalReasoning(
            cleanedList(technicalReasoning, fallback: []),
            technicalCompetencies: repairedTechnicalCompetencies
        )

        return InterviewFeedback(
            summary: clean(summary, fallback: "Your interview answers were reviewed against the role requirements. Use the notes below as practice feedback, not as a hiring prediction."),
            technicalCompetencies: repairedTechnicalCompetencies,
            behavioralCompetencies: repairedBehavioralCompetencies,
            strengths: strengths.compactMap(\.feedbackPoint),
            improvements: improvements.compactMap(\.feedbackPoint),
            starQuestion: clean(starQuestion, fallback: "Behavioral answer"),
            starAssessments: hasBehavioralAnswer(in: answers) ? repairedSTARAssessments : [],
            technicalReasoning: repairedTechnicalReasoning,
            improvedAnswerQuestion: validGeneratedText(improvedAnswerQuestion) ?? "",
            improvedAnswer: validGeneratedText(improvedAnswer) ?? "",
            recommendations: Array(cleanedList(recommendations, fallback: []).prefix(3))
        )
    }

    private func repairedCompetencies(
        generated: [GeneratedCompetencyAssessment],
        allowedNames: [String]
    ) -> [CompetencyAssessment] {
        let cleanedAllowedNames = allowedNames.compactMap(validGeneratedText)
        guard !cleanedAllowedNames.isEmpty else { return [] }

        return cleanedAllowedNames.map { allowedName in
            let generatedAssessment = generated.first { assessment in
                namesMatch(generatedName: assessment.name, allowedName: allowedName)
            }
            let note = normalizedCompetencyNote(generatedAssessment?.note)
            return CompetencyAssessment(name: allowedName, note: note)
        }
    }

    private var repairedSTARAssessments: [STARAssessment] {
        let generated = starAssessments.compactMap(\.starAssessment)
        let requiredLabels = ["Situation", "Task", "Action", "Result"]

        return requiredLabels.map { label in
            guard let assessment = generated.first(where: { namesMatch(generatedName: $0.label, allowedName: label) }) else {
                return STARAssessment(
                    label: label,
                    present: false,
                    note: "\(label) was not clearly covered in the transcript."
                )
            }

            let note = clean(assessment.note, fallback: "\(label) was not clearly covered in the transcript.")
            let present = assessment.present && !noteImpliesMissingSTARDetail(note)
            return STARAssessment(
                label: label,
                present: present,
                note: note
            )
        }
    }

    private func cleanedList(_ items: [String], fallback: [String]) -> [String] {
        let cleanedItems = items
            .compactMap(validGeneratedText)
        return cleanedItems.isEmpty ? fallback : cleanedItems
    }

    private func clean(_ value: String, fallback: String) -> String {
        validGeneratedText(value) ?? fallback
    }

    private func hasBehavioralAnswer(in answers: [InterviewAnswer]) -> Bool {
        answers.contains { $0.questionKind == .behavioral }
    }

    private func namesMatch(generatedName: String, allowedName: String) -> Bool {
        let generated = normalizedName(generatedName)
        let allowed = normalizedName(allowedName)
        guard !generated.isEmpty, !allowed.isEmpty else { return false }
        return generated == allowed || generated.contains(allowed) || allowed.contains(generated)
    }

    private func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizedCompetencyNote(_ note: String?) -> String {
        guard let note = note?.lowercased() else { return "Not covered" }

        if note.contains("not covered")
            || note.contains("not mentioned")
            || note.contains("not discussed")
            || note.contains("no evidence")
            || note.contains("missing")
            || note.contains("did not") {
            return "Not covered"
        }

        if note.contains("partly")
            || note.contains("partial")
            || note.contains("some")
            || note.contains("limited")
            || note.contains("unclear")
            || note.contains("needs") {
            return "Partly explained"
        }

        if note.contains("clear")
            || note.contains("covered")
            || note.contains("explained")
            || note.contains("specific")
            || note.contains("strong") {
            return "Clearly explained"
        }

        return "Partly explained"
    }

    private func consistencyCheckedTechnicalReasoning(
        _ notes: [String],
        technicalCompetencies: [CompetencyAssessment]
    ) -> [String] {
        notes.filter { note in
            !positivelyClaimsNotCoveredCompetency(
                in: note,
                technicalCompetencies: technicalCompetencies
            )
        }
    }

    private func positivelyClaimsNotCoveredCompetency(
        in note: String,
        technicalCompetencies: [CompetencyAssessment]
    ) -> Bool {
        guard noteHasPositiveAssessmentLanguage(note) else { return false }

        return technicalCompetencies.contains { assessment in
            assessment.note == "Not covered" && namesMatch(
                generatedName: note,
                allowedName: assessment.name
            )
        }
    }

    private func noteHasPositiveAssessmentLanguage(_ note: String) -> Bool {
        let normalizedNote = note.lowercased()
        return normalizedNote.contains("clear")
            || normalizedNote.contains("good")
            || normalizedNote.contains("strong")
            || normalizedNote.contains("demonstrated")
            || normalizedNote.contains("explained")
            || normalizedNote.contains("understanding")
            || normalizedNote.contains("well")
    }

    private func noteImpliesMissingSTARDetail(_ note: String) -> Bool {
        let normalizedNote = note.lowercased()
        return normalizedNote.contains("not provide")
            || normalizedNote.contains("not provided")
            || normalizedNote.contains("did not")
            || normalizedNote.contains("missing")
            || normalizedNote.contains("lacks")
            || normalizedNote.contains("lack ")
            || normalizedNote.contains("unclear")
            || normalizedNote.contains("not clearly")
            || normalizedNote.contains("no specific")
            || normalizedNote.contains("without specific")
            || normalizedNote.contains("needs improvement")
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
