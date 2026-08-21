import Foundation

/// Supported mock interview lengths, expressed in minutes.
enum InterviewDuration: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case fifteen = 15

    var id: Int { rawValue }
    var title: String { "\(rawValue) minutes" }
}
