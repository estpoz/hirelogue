import Foundation

/// Captures the candidate's transcript for one primary question and its optional follow-up.
struct InterviewAnswer: Identifiable, Equatable {
    let id: String
    let questionID: String
    let questionKind: InterviewQuestion.Kind
    let competency: String
    let questionText: String
    let primaryTranscript: String
    let followUpQuestion: String?
    let followUpTranscript: String?
}
