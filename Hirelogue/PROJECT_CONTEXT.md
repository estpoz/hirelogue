# Hirelogue Project Context

Use this file as the first-read handoff for future coding chats.

## App Purpose

Hirelogue is an English-language AI interview practice assistant for iPhone.

The intended final flow is:
1. The user pastes a complete job opening.
2. The app analyzes the role, responsibilities, qualifications, and competencies.
3. The user configures a turn-based voice interview.
4. The app conducts an automatic voice interview.
5. The app returns structured feedback.

## Current Milestone

This project is currently an app-base prototype with focused real integrations for job-opening analysis, interview-question generation, and spoken interviewer prompts.

The app now implements:
- Foundation Models job-profile extraction for pasted job openings.
- Foundation Models primary interview-question generation from the user-confirmed, edited `JobProfile`.
- Guided generation into structured Swift types, then mapping into the app's domain models.
- A deterministic mock fallback when Foundation Models is unavailable, not linked, or fails generation.
- UI status messaging during analysis/question generation and setup-screen fallback notices.
- AVSpeechSynthesizer playback for interviewer questions during the session's speaking phase.

The app still does not implement:
- Foundation Models follow-up generation from transcribed answers
- Foundation Models answer analysis or final feedback generation
- Speech recognition
- Live transcription
- Microphone capture
- Audio recording
- AVAudioEngine processing

The app does request microphone permission before starting the mock interview because the final product will be voice-based.

## Architecture

The app uses a simple MVVM structure:

- `Views/`: SwiftUI screens.
- `Components/`: reusable SwiftUI UI pieces.
- `Models/`: one file per domain model or enum.
- `ViewModels/`: observable app/session state.
- `Services/`: narrow service boundaries for real app capabilities, starting with job-opening analysis.
- `Mock/`: static fixture data used by the prototype and fallback paths.

The main source of truth is `InterviewSessionViewModel`. Views render state from this view model and call its methods for user actions. Real AI work should stay behind service protocols rather than being embedded directly in views.

## Navigation Flow

Navigation is managed by `ContentView` with a single `NavigationStack` and `AppRoute` path.

Flow:

```text
HomeJobInputView
  -> InterviewSetupView
  -> InterviewSessionView
  -> InterviewFeedbackView
```

Rules:
- No tab bar.
- Native back navigation is allowed outside the active interview.
- `InterviewSessionView` hides the back button to prevent accidental exits.
- Ending an active interview requires confirmation.
- `Practise Again` returns to setup while preserving the analyzed job profile.
- `Back to Home` resets the view model and returns to Home.

## Data Flow

1. `HomeJobInputView` writes job-opening text into `InterviewSessionViewModel.jobOpening`.
2. `Use Example` fills `jobOpening` from `MockHirelogueData.exampleJobOpening`.
3. `Analyze Job Opening` calls `analyzeJobOpening(onComplete:)`.
4. The view model updates analysis progress/status and calls `JobAnalysisService`.
5. `FoundationModelJobAnalysisService` checks `SystemLanguageModel.default.availability`, uses guided generation to extract a structured profile, and maps it into `JobProfile`.
6. If Foundation Models is unavailable or generation fails, `MockJobAnalysisService` supplies `MockHirelogueData.jobProfile` and `analysisErrorMessage` is shown on setup.
7. The view model sets `jobProfile`, then `ContentView` navigates to `.setup`.
8. `InterviewSetupView` reads and edits `jobProfile`, `interviewType`, and `duration`.
9. `Start Interview` calls `generateInterviewQuestionsForCurrentProfile()`.
10. `FoundationModelInterviewQuestionService` generates primary questions from the edited profile, selected type, and selected duration.
11. Generated questions are stored in `InterviewSessionViewModel.questions` and printed to the Xcode console.
12. `Start Interview` calls `requestMicrophonePermission()`.
13. If permission is granted, `startInterview()` resets session state and starts timers.
14. `InterviewSessionView` renders `phase`, question progress, remaining time, and current question.
15. During `.speaking`, `SpeechSynthesisService` speaks `currentQuestionText` aloud and then advances to `.listening`.
16. When the mock interview finishes, the view model sets `shouldShowFeedback = true`.
17. `InterviewSessionView` calls `onShowFeedback`, and `ContentView` navigates to `.feedback`.
18. `InterviewFeedbackView` renders `MockHirelogueData.feedback` through the view model.

## Major Files

### App Root

- `HirelogueApp.swift`
  - App entry point.
  - Installs `ContentView` in the main window.

- `ContentView.swift`
  - Owns the shared `InterviewSessionViewModel`.
  - Owns the `NavigationStack` route path.
  - Shows `SplashScreenView` on launch.
  - Coordinates screen-to-screen navigation.

### Views

- `HomeJobInputView.swift`
  - First screen.
  - Lets the user paste a job opening.
  - Has `Use Example` and `Analyze Job Opening` actions.
  - Shows an analysis loading overlay.
  - Uses light/dark logo text assets in the navigation bar.

- `InterviewSetupView.swift`
  - Lets the user review mock extracted job data.
  - Lets the user edit position and seniority.
  - Lets the user remove competencies.
  - Lets the user choose interview type and duration.
  - Requests microphone permission before starting the mock interview.

- `InterviewSessionView.swift`
  - Simulates the future voice-interview experience.
  - Shows progress, remaining time, current question, and interview phase.
  - Shows no transcript.
  - Provides prototype demo controls for jumping between phases.
  - Confirms before ending the interview.

- `InterviewFeedbackView.swift`
  - Shows structured mock feedback.
  - Includes summary, competencies, strengths, improvements, STAR structure, technical reasoning, improved answer, and practice areas.
  - Handles `Practise Again` and `Back to Home`.

- `SplashScreenView.swift`
  - Launch overlay.
  - Animates `logoWithText` or `darkLogoWithText` depending on color scheme.

### Components

- `HirelogueComponents.swift`
  - Shared native SwiftUI UI components.
  - Includes screen/action containers, grouped cards, rows, bullet lists, tags, progress bars, interview phase indicators, feedback cards, empty states, and `FlowLayout`.
  - Includes component previews for quick visual inspection.

### View Models

- `InterviewSessionViewModel.swift`
  - Main observable state holder.
  - Uses Swift Observation with `@Observable`.
  - Owns job input, extracted profile, generated questions, configuration, permission state, interview state, timers, completion state, and feedback fixtures.
  - Calls `JobAnalysisService` for job-profile extraction and falls back to mock data when needed.
  - Calls `InterviewQuestionService` for primary question generation from the edited profile.
  - Calls `SpeechSynthesisService` during `.speaking` to ask questions aloud.
  - Simulates listening, pause, processing, and feedback transitions.
  - Calls `AVAudioApplication.requestRecordPermission()` for microphone permission.

### Services

- `JobAnalysisService.swift`
  - Defines the `JobAnalysisService` protocol.
  - Implements `FoundationModelJobAnalysisService` for on-device Foundation Models job-profile extraction.
  - Uses guided generation with `@Generable` and `@Guide` to produce structured analysis output.
  - Maps generated output into the existing `JobProfile` model.
  - Implements `MockJobAnalysisService` as a deterministic fallback.

- `InterviewQuestionService.swift`
  - Defines the `InterviewQuestionService` protocol.
  - Implements `FoundationModelInterviewQuestionService` for primary question generation from the edited job profile.
  - Limits primary questions by selected duration and caps the plan at five questions.
  - Generates primary questions only; answer-based follow-ups are future work.
  - Implements `MockInterviewQuestionService` as a deterministic fallback.

- `SpeechSynthesisService.swift`
  - Defines the `SpeechSynthesisService` protocol.
  - Implements `InterviewSpeechSynthesisService` with `AVSpeechSynthesizer`.
  - Speaks interviewer questions aloud and resumes the phase machine when speech finishes or is cancelled.

### Mock Data

- `MockHirelogueData.swift`
  - Contains all static prototype data.
  - Includes example job opening, fallback job profile, mock interview questions, and mock structured feedback.
  - Keep this as fallback data until each real AI/speech capability has its own reliable implementation.

### Models

- `AppRoute.swift`
  - Navigation destinations pushed by `ContentView`.

- `InterviewType.swift`
  - Interview mode: Mixed, Technical, Behavioral.

- `InterviewDuration.swift`
  - Supported mock durations: 5, 10, 15 minutes.

- `InterviewPhase.swift`
  - Mock session phases: speaking, listening, paused, processing, finished.
  - Provides user-facing title, instruction, and status text.

- `JobProfile.swift`
  - Mock extracted job analysis output.
  - Contains position, seniority, responsibilities, qualifications, and competencies.

- `InterviewQuestion.swift`
  - A planned mock interview question.
  - Includes kind, prompt text, competency, and optional follow-up.

- `CompetencyAssessment.swift`
  - Feedback tag model with a competency name and assessment note.

- `FeedbackPoint.swift`
  - Reusable feedback item for strengths and improvement areas.

- `STARAssessment.swift`
  - One part of STAR feedback: Situation, Task, Action, or Result.

- `InterviewFeedback.swift`
  - Full structured feedback payload shown after the mock interview.

### Configuration

- `Info.plist`
  - Contains `NSMicrophoneUsageDescription`.
  - Required before requesting microphone permission.

## Current Assets

The app uses these asset names:

- `logoWithText`
- `darkLogoWithText`
- `logoTextOnly`
- `darkLogoTextOnly`
- `logoOnly`
- app icon asset: `hirelogueLogo.icon`

## Important Implementation Boundaries

When continuing development:

- Keep code SwiftUI-native.
- Keep one file per model.
- Keep real AI/audio/speech functionality behind service boundaries.
- Do not add audio capture, speech recognition, live transcription, answer-based follow-up generation, answer analysis, or generated feedback unless the milestone explicitly asks for it.
- Do not show a live transcript unless explicitly requested.
- Prefer adding service types before expanding `InterviewSessionViewModel` too much.
- Keep `InterviewSessionViewModel` as the single source of truth until there is a real reason to split it.
- Preserve the app's simple linear navigation flow unless the product scope changes.
- Build after changes with Xcode.

## Service Boundaries

Current services:

```text
Services/
  JobAnalysisService.swift
  InterviewQuestionService.swift
  SpeechSynthesisService.swift
```

Suggested future service boundaries:

```text
Services/
  MicrophonePermissionService.swift
  AnswerAnalysisService.swift
  FeedbackService.swift
  SpeechRecognitionService.swift
```

Do not add future services early unless they remove real complexity.

## Verification Checklist for Future Changes

Before handing off:

1. Confirm the project builds successfully.
2. Confirm Home -> Setup -> Session -> Feedback still works.
3. Confirm `Practise Again` preserves the job profile.
4. Confirm `Back to Home` resets the session.
5. Confirm the active interview cannot be accidentally popped with the default back button.
6. Confirm microphone permission still has a valid `NSMicrophoneUsageDescription` string.
7. Confirm no unintended real audio, speech, or AI functionality was added for app-base work.
