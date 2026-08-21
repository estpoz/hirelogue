import Foundation

/// A competency label plus the mock assessment note shown on feedback.
struct CompetencyAssessment: Identifiable, Equatable {
    let name: String
    let note: String

    var id: String { name }
}
