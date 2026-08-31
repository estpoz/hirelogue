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

This project is currently an app-base prototype with focused real integrations for job-opening analysis, interview-question generation, spoken interviewer prompts, live answer transcription, and answer-based follow-up generation.

The app now implements:
- Foundation Models job-profile extraction for pasted job openings.
- Foundation Models primary interview-question generation from the user-confirmed, edited `JobProfile`.
- Guided generation into structured Swift types, then mapping into the app's domain models.
- A deterministic mock fallback when Foundation Models is unavailable, not linked, or fails generation.
- UI status messaging during analysis/question generation and setup-screen fallback notices.
- AVSpeechSynthesizer playback for interviewer questions during the session's speaking phase.
- SpeechAnalyzer/SpeechTranscriber transcription for spoken user answers, with `SFSpeechRecognizer` fallback when SpeechAnalyzer assets are unavailable.
- AVAudioEngine microphone capture with route stabilization and audio conversion for SpeechAnalyzer.
- Silence-based turn taking: after 3 seconds of no transcript activity, the app enters a paused warning state; after 3 more seconds, it finalizes the answer.
- A `Done Answering` action that lets users submit the current answer without waiting for silence finalization.
- Full-answer transcript preservation across `.listening` and `.paused`, so Foundation Models receives one whole answer for the current turn.
- Foundation Models follow-up decisions from the finalized answer transcript, bounded to one follow-up per primary question.

The app still does not implement:
- Foundation Models answer analysis or final feedback generation
- Audio recording

The app requests both microphone and speech recognition permissions before starting the voice interview.

The app currently shows a live transcript during the interview as a development validation surface. The product scope still treats in-session transcript display as optional/temporary rather than a final user-facing requirement.

## Architecture

The app uses a simple MVVM structure:

- `Views/`: SwiftUI screens.
- `Components/`: reusable SwiftUI UI pieces.
- `Models/`: one file per domain model or enum.
- `ViewModels/`: observable app/session state.
- `Services/`: narrow service boundaries for AI, speech, transcription, and audio-backed app capabilities.
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
12. `Start Interview` calls `requestInterviewAudioPermissions()` for microphone and speech recognition access.
13. If permissions are granted, `startInterview()` resets session state and starts the interview phase machine.
14. `InterviewSessionView` renders `phase`, question progress, remaining time, and current question.
15. During `.speaking`, `SpeechSynthesisService` speaks `currentQuestionText` aloud and then advances to `.listening`.
16. During `.listening`, `SpeechTranscriptionService` streams microphone audio into SpeechAnalyzer/SpeechTranscriber, or falls back to `SFSpeechRecognizer`.
17. `InterviewSessionViewModel` preserves the best full transcript for the current answer across `.listening` and `.paused`.
18. If transcript activity stops for 3 seconds, the app enters `.paused`; if the user resumes speaking, it returns to `.listening`; if silence continues for 3 more seconds, it enters `.processing`.
19. The user can also tap `Done Answering` to move directly to `.processing`.
20. During `.processing`, `AnswerFollowUpService` sends the finalized answer transcript to Foundation Models to decide whether one follow-up is needed.
21. If a follow-up is needed, `generatedFollowUpQuestion` is spoken aloud; otherwise the app advances to the next primary question.
22. Follow-up answers move to the next primary question and do not generate another follow-up.
23. When the interview finishes, the view model sets `shouldShowFeedback = true`.
24. `InterviewSessionView` calls `onShowFeedback`, and `ContentView` navigates to `.feedback`.
25. `InterviewFeedbackView` renders `MockHirelogueData.feedback` through the view model.

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
  - Generates the primary question plan before starting the interview.
  - Requests microphone and speech recognition permissions before starting the voice interview.

- `InterviewSessionView.swift`
  - Presents the voice-interview experience.
  - Shows progress, remaining time, current question, interview phase, and a temporary live transcript validation card.
  - Shows a `Done Answering` button during answer capture and paused warning states.
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
  - Calls `SpeechTranscriptionService` during `.listening` and `.paused` to capture the user's answer.
  - Preserves one full answer transcript per turn and sends that transcript to Foundation Models during `.processing`.
  - Calls `AnswerFollowUpService` to decide whether one generated follow-up should be asked.
  - Owns silence-based transition logic, the `Done Answering` action, and feedback navigation.
  - Calls `AVAudioApplication.requestRecordPermission()` and `SFSpeechRecognizer.requestAuthorization()` through service boundaries.

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
  - Generates primary questions only; answer-based follow-ups are handled later by `AnswerFollowUpService`.
  - Implements `MockInterviewQuestionService` as a deterministic fallback.

- `AnswerFollowUpService.swift`
  - Defines `AnswerFollowUpService` and `AnswerFollowUpDecision`.
  - Implements `FoundationModelAnswerFollowUpService` for transcript-based follow-up decisions.
  - Uses guided generation to return `needsFollowUp`, `reason`, and an optional follow-up question.
  - Keeps the interview bounded to one follow-up per primary question through view-model control flow.
  - Implements `MockAnswerFollowUpService` as a conservative no-follow-up fallback.

- `SpeechSynthesisService.swift`
  - Defines the `SpeechSynthesisService` protocol.
  - Implements `InterviewSpeechSynthesisService` with `AVSpeechSynthesizer`.
  - Speaks interviewer questions aloud and resumes the phase machine when speech finishes or is cancelled.

- `SpeechTranscriptionService.swift`
  - Defines the `SpeechTranscriptionService` protocol.
  - Implements `SpeechAnalyzerTranscriptionService` with SpeechAnalyzer/SpeechTranscriber as the preferred path.
  - Falls back to `SFSpeechRecognizer` when SpeechAnalyzer assets are unavailable.
  - Uses AVAudioEngine for microphone capture.
  - Stabilizes the audio route before installing a tap.
  - Converts microphone buffers into SpeechAnalyzer-compatible audio before yielding `AnalyzerInput`.

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
  - Contains `NSSpeechRecognitionUsageDescription`.
  - Required before requesting microphone and speech recognition permissions.

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
- Do not add final feedback generation or scoring unless the milestone explicitly asks for it.
- The live transcript is currently visible only because it was explicitly requested for transcription validation.
- Prefer adding service types before expanding `InterviewSessionViewModel` too much.
- Keep `InterviewSessionViewModel` as the single source of truth until there is a real reason to split it.
- Preserve the app's simple linear navigation flow unless the product scope changes.
- Build after changes with Xcode.

## Service Boundaries

Current services:

```text
Services/
  AnswerFollowUpService.swift
  JobAnalysisService.swift
  InterviewQuestionService.swift
  SpeechSynthesisService.swift
  SpeechTranscriptionService.swift
```

Suggested future service boundaries:

```text
Services/
  MicrophonePermissionService.swift
  AnswerAnalysisService.swift
  FeedbackService.swift
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
7. Confirm speech recognition permission still has a valid `NSSpeechRecognitionUsageDescription` string.
8. Confirm the transcript shown in the session matches the final transcript printed in the follow-up decision block.
9. Confirm follow-up generation remains bounded to one follow-up per primary question.
