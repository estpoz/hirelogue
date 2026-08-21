import Foundation

/// Mock output that represents the future job-opening analysis result.
struct JobProfile: Equatable {
    var position: String
    var seniority: String
    var responsibilities: [String]
    var requiredQualifications: [String]
    var preferredQualifications: [String]
    var technicalCompetencies: [String]
    var behavioralCompetencies: [String]
}
