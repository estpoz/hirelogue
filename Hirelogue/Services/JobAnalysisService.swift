import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Service Contract

/// Extracts a structured job profile from a pasted job opening.
protocol JobAnalysisService {
    func analyze(jobOpening: String) async throws -> JobProfile
}

// MARK: - Foundation Models Analyzer

/// Uses Apple's on-device Foundation Models framework when it is available.
struct FoundationModelJobAnalysisService: JobAnalysisService {
    nonisolated init() {}

    func analyze(jobOpening: String) async throws -> JobProfile {
#if canImport(FoundationModels)
        let trimmedOpening = jobOpening.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOpening.isEmpty else {
            throw JobAnalysisError.emptyJobOpening
        }

        // Apple Intelligence can be unavailable on unsupported devices, disabled systems, or while assets are still preparing.
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw JobAnalysisError.foundationModelUnavailable(model.availability.availabilityDescription)
        }

        // Instructions define the model's durable behavior; the pasted job opening stays in the lower-priority prompt.
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You extract job-opening information for an interview practice app.
            Return only information supported by the job opening. Keep every list concise and useful for interview preparation.
            The interview language is English.
            """
        )

        let prompt = """
        Analyze this job opening and extract a structured job profile.

        Requirements:
        - Infer seniority only when the text supports it.
        - Use concise noun phrases for competencies.
        - Keep responsibilities and qualifications specific to the pasted role.
        - Do not invent company research or resume details.

        Job opening:
        \(trimmedOpening)
        """

        // Guided generation returns a Swift value, avoiding manual JSON or string parsing.
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedJobProfile.self
        )
        return response.content.jobProfile
#else
        throw JobAnalysisError.foundationModelsNotLinked
#endif
    }
}

// MARK: - Prototype Fallback

/// Deterministic fallback that preserves the prototype flow when Apple Intelligence is unavailable.
struct MockJobAnalysisService: JobAnalysisService {
    nonisolated init() {}

    func analyze(jobOpening: String) async throws -> JobProfile {
        MockHirelogueData.jobProfile
    }
}

// MARK: - Analysis Errors

enum JobAnalysisError: LocalizedError {
    case emptyJobOpening
    case foundationModelsNotLinked
    case foundationModelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .emptyJobOpening:
            return "Paste a job opening before analyzing."
        case .foundationModelsNotLinked:
            return "Foundation Models is not available in this build."
        case .foundationModelUnavailable(let reason):
            return "Foundation Models is unavailable: \(reason)."
        }
    }
}

#if canImport(FoundationModels)

// MARK: - Guided Generation Schema

@Generable(description: "A structured profile extracted from a job opening")
private struct GeneratedJobProfile {
    @Guide(description: "Job title or role name")
    var position: String

    @Guide(description: "Seniority level, or Not specified")
    var seniority: String

    @Guide(description: "Core responsibilities from the job opening")
    var responsibilities: [String]

    @Guide(description: "Required qualifications from the job opening")
    var requiredQualifications: [String]

    @Guide(description: "Preferred or nice-to-have qualifications")
    var preferredQualifications: [String]

    @Guide(description: "Technical skills and concepts to assess")
    var technicalCompetencies: [String]

    @Guide(description: "Behavioral competencies to assess")
    var behavioralCompetencies: [String]

    /// Converts model output into the app's existing domain model and normalizes empty strings/lists.
    var jobProfile: JobProfile {
        JobProfile(
            position: cleaned(position, fallback: "Unknown Role"),
            seniority: cleaned(seniority, fallback: "Not specified"),
            responsibilities: cleanedList(responsibilities),
            requiredQualifications: cleanedList(requiredQualifications),
            preferredQualifications: cleanedList(preferredQualifications),
            technicalCompetencies: cleanedList(technicalCompetencies),
            behavioralCompetencies: cleanedList(behavioralCompetencies)
        )
    }

    private func cleaned(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func cleanedList(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
