/// Central location for static prototype data.
///
/// Replace these fixtures when the app starts using real job analysis, generated
/// interview questions, and generated feedback.
enum MockHirelogueData {
    // MARK: - Job Opening Input

    /// Complete sample opening used by the Home screen's "Use Example" action.
    static let exampleJobOpening = """
    iOS Developer (Mid-Level) - Nordic Fintech Group, Amsterdam (Hybrid)

    About the role
    We are looking for a mid-level iOS Developer to join our Mobile Payments team. You will work on our consumer banking app used by 1.2 million customers, collaborating closely with designers, backend engineers and product managers.

    Responsibilities
    - Build and maintain features in Swift and SwiftUI for our consumer banking app
    - Collaborate with backend engineers on REST APIs and data models
    - Write unit and UI tests and keep the CI pipeline green
    - Participate in code reviews and improve architecture (MVVM)
    - Monitor crash reports and performance metrics, and resolve production issues

    Required qualifications
    - 3+ years of professional iOS development experience
    - Strong Swift skills and solid understanding of UIKit and SwiftUI
    - Experience with concurrency (async/await, GCD)
    - Experience with dependency injection and modular app architecture
    - Familiarity with Git and pull-request based workflows

    Preferred qualifications
    - Experience in fintech or another regulated industry
    - Experience with Combine
    - Experience with accessibility (VoiceOver, Dynamic Type)
    - Exposure to App Store release management and phased rollouts
    """

    // MARK: - Mock Analysis Result

    /// Pretend extracted profile returned after the simulated analysis step.
    static let jobProfile = JobProfile(
        position: "iOS Developer",
        seniority: "Mid-level (3-5 years)",
        responsibilities: [
            "Build and maintain Swift and SwiftUI features in a consumer banking app",
            "Collaborate with backend engineers on REST APIs and data models",
            "Write unit and UI tests and keep the CI pipeline healthy",
            "Improve app architecture using MVVM and modularisation",
            "Investigate crash reports and production performance issues"
        ],
        requiredQualifications: [
            "3+ years of professional iOS development",
            "Strong Swift, UIKit and SwiftUI knowledge",
            "Concurrency with async/await and GCD",
            "Dependency injection and modular architecture",
            "Git and pull-request based workflows"
        ],
        preferredQualifications: [
            "Fintech or regulated-industry experience",
            "Combine framework",
            "Accessibility: VoiceOver and Dynamic Type",
            "App Store release management and phased rollouts"
        ],
        technicalCompetencies: [
            "Swift",
            "SwiftUI",
            "UIKit",
            "MVVM",
            "Concurrency",
            "Testing",
            "REST APIs",
            "Performance"
        ],
        behavioralCompetencies: [
            "Collaboration",
            "Ownership",
            "Communication",
            "Problem solving",
            "Handling pressure"
        ]
    )

    // MARK: - Mock Interview Questions

    /// Ordered question plan used by the simulated interview state machine.
    static let questions: [InterviewQuestion] = [
        InterviewQuestion(
            id: "q1",
            kind: .behavioral,
            text: "To start, tell me about a recent iOS feature you owned end to end. What was your role and what did you deliver?",
            competency: "Ownership",
            followUp: "You mentioned the release was delayed a week. What would you do differently to catch that risk earlier?"
        ),
        InterviewQuestion(
            id: "q2",
            kind: .technical,
            text: "This role mixes UIKit and SwiftUI. How do you decide which to use for a new screen, and how do you make the two work together?",
            competency: "SwiftUI",
            followUp: nil
        ),
        InterviewQuestion(
            id: "q3",
            kind: .technical,
            text: "Walk me through how you would move a screen that uses completion handlers to async/await without breaking existing callers.",
            competency: "Concurrency",
            followUp: nil
        ),
        InterviewQuestion(
            id: "q4",
            kind: .behavioral,
            text: "Describe a time you disagreed with a backend engineer about an API contract. How did you handle it?",
            competency: "Collaboration",
            followUp: nil
        ),
        InterviewQuestion(
            id: "q5",
            kind: .technical,
            text: "A payments screen shows a spike in crashes after release. How do you investigate and reduce the crash rate?",
            competency: "Performance",
            followUp: nil
        )
    ]

    // MARK: - Mock Feedback

    /// Structured practice feedback shown after the mock interview completes.
    static let feedback = InterviewFeedback(
        summary: "You gave concrete, well-paced answers and were strongest when describing architecture decisions you made yourself. Behavioral answers often ended before the result, and two technical answers stayed at a high level. This is practice feedback only; it does not predict a hiring outcome.",
        technicalCompetencies: [
            CompetencyAssessment(name: "SwiftUI", note: "Clearly explained"),
            CompetencyAssessment(name: "Concurrency", note: "Partly explained"),
            CompetencyAssessment(name: "MVVM", note: "Clearly explained"),
            CompetencyAssessment(name: "Testing", note: "Not covered"),
            CompetencyAssessment(name: "Performance", note: "Partly explained")
        ],
        behavioralCompetencies: [
            CompetencyAssessment(name: "Ownership", note: "Clearly explained"),
            CompetencyAssessment(name: "Collaboration", note: "Clearly explained"),
            CompetencyAssessment(name: "Communication", note: "Partly explained"),
            CompetencyAssessment(name: "Handling pressure", note: "Not covered")
        ],
        strengths: [
            FeedbackPoint(point: "You named specific technical decisions instead of generic tooling.", detail: "We moved the payment list to SwiftUI first because the layout changed every sprint, and kept the card detail in UIKit for the custom transition."),
            FeedbackPoint(point: "You described collaboration in behavior, not adjectives.", detail: "I wrote the API contract in a shared doc, and we reviewed it in a 20-minute call before either side started building."),
            FeedbackPoint(point: "You referenced measurable outcomes when prompted.", detail: "Crash-free sessions went from 99.1% to 99.7% over two releases.")
        ],
        improvements: [
            FeedbackPoint(point: "The concurrency answer skipped the migration strategy.", detail: "You explained what async/await is but not how you would keep existing completion-handler callers working during the change."),
            FeedbackPoint(point: "Testing was never mentioned, although the opening requires it.", detail: "Add one example of a test you wrote and what regression it caught."),
            FeedbackPoint(point: "Two answers ended without a result.", detail: "Close each behavioral answer with the measurable or human outcome, even a small one.")
        ],
        starQuestion: "Tell me about a recent iOS feature you owned end to end.",
        starAssessments: [
            STARAssessment(label: "Situation", present: true, note: "You set the scene: a payments list rewrite in a 1.2M-user app."),
            STARAssessment(label: "Task", present: true, note: "Your responsibility was clear: you owned the client side."),
            STARAssessment(label: "Action", present: true, note: "Good detail on the SwiftUI/UIKit split and the MVVM refactor."),
            STARAssessment(label: "Result", present: false, note: "Missing. The answer stopped at shipping; no impact on users, performance or the team.")
        ],
        technicalReasoning: [
            "You explained trade-offs out loud, which made your decisions easy to follow.",
            "You tended to state a conclusion before the constraint that caused it. Lead with the constraint.",
            "Avoid framework names as an answer on their own; say what problem the framework solved here."
        ],
        improvedAnswerQuestion: "Migrating completion handlers to async/await",
        improvedAnswer: "I would wrap the existing completion-handler API with withCheckedThrowingContinuation so callers keep working, expose an async version alongside it, then migrate call sites screen by screen behind a feature flag. Once every caller is async I delete the old method. I did something similar for our transactions service, and it let us ship in three PRs instead of one risky one.",
        recommendations: [
            "Practise closing every behavioral answer with a concrete result.",
            "Prepare one testing story: what you tested, why, and what it caught.",
            "Rehearse a step-by-step concurrency migration out loud in under 90 seconds."
        ]
    )
}
