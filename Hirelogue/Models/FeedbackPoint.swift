import Foundation

/// A reusable feedback item used for strengths and improvement areas.
struct FeedbackPoint: Identifiable, Equatable {
    let point: String
    let detail: String?

    var id: String { point }
}
