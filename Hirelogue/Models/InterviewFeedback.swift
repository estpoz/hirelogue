import Foundation

/// Complete mock feedback payload displayed after the interview.
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
