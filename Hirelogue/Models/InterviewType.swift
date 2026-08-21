import Foundation

/// High-level interview modes the user can choose during setup.
enum InterviewType: String, CaseIterable, Identifiable {
    case mixed = "Mixed"
    case technical = "Technical"
    case behavioral = "Behavioral"

    var id: String { rawValue }
}
