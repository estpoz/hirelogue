import Foundation

enum InterviewType: String, CaseIterable, Identifiable {
    case mixed = "Mixed"
    case technical = "Technical"
    case behavioral = "Behavioral"

    var id: String { rawValue }
}

enum InterviewDuration: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case fifteen = 15

    var id: Int { rawValue }
    var title: String { "\(rawValue) minutes" }
}

enum InterviewPhase: String, CaseIterable, Identifiable {
    case speaking
    case listening
    case paused
    case processing
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speaking: "Interviewer is speaking"
        case .listening: "Listening"
        case .paused: "Still answering?"
        case .processing: "Reviewing your answer"
        case .finished: "Interview complete"
        }
    }

    var instruction: String {
        switch self {
        case .speaking: "Listen to the question. Recording starts automatically in the finished app."
        case .listening: "Answer naturally. The interview continues when you finish."
        case .paused: "Continue speaking to keep answering."
        case .processing: "Preparing the next question."
        case .finished: "Preparing your feedback."
        }
    }

    var status: String {
        switch self {
        case .speaking: "Not listening yet"
        case .listening: "Microphone simulated"
        case .paused: "Waiting for you"
        case .processing: "Processing"
        case .finished: "Finishing up"
        }
    }
}

struct JobProfile: Equatable {
    var position: String
    var seniority: String
    var responsibilities: [String]
    var requiredQualifications: [String]
    var preferredQualifications: [String]
    var technicalCompetencies: [String]
    var behavioralCompetencies: [String]
}

struct InterviewQuestion: Identifiable, Equatable {
    enum Kind: String {
        case technical
        case behavioral
    }

    let id: String
    let kind: Kind
    let text: String
    let competency: String
    let followUp: String?
}

struct CompetencyAssessment: Identifiable, Equatable {
    let name: String
    let note: String

    var id: String { name }
}

struct FeedbackPoint: Identifiable, Equatable {
    let point: String
    let detail: String?

    var id: String { point }
}

struct STARAssessment: Identifiable, Equatable {
    let label: String
    let present: Bool
    let note: String

    var id: String { label }
}

struct InterviewFeedback: Equatable {
    let summary: String
    let technicalCompetencies: [CompetencyAssessment]
    let behavioralCompetencies: [CompetencyAssessment]
    let strengths: [FeedbackPoint]
    let improvements: [FeedbackPoint]
    let starQuestion: String
    let starAssessments: [STARAssessment]
    let technicalReasoning: [String]
    let improvedAnswerQuestion: String
    let improvedAnswer: String
    let recommendations: [String]
}

enum AppRoute: Hashable {
    case setup
    case session
    case feedback
}
