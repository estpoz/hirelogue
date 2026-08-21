import Foundation

/// Represents one part of the STAR answer structure.
struct STARAssessment: Identifiable, Equatable {
    let label: String
    let present: Bool
    let note: String

    var id: String { label }
}
