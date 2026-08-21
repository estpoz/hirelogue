import Foundation

/// One planned interview question and its optional follow-up prompt.
struct InterviewQuestion: Identifiable, Equatable {
    /// Separates technical and behavioral questions for future filtering.
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
