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

This project is currently an app-base prototype with focused real integrations for job-opening analysis, interview-question generation, spoken interviewer prompts, live answer transcription, answer-based follow-up generation, transcript confirmation, and final feedback generation.

The app now implements:
- Foundation Models job-profile extraction for pasted job openings.
- Foundation Models primary interview-question generation from the user-confirmed, edited `JobProfile`.
- Guided generation into structured Swift types, then mapping into the app's domain models.
- A deterministic mock fallback when Foundation Models is unavailable, not linked, or fails generation.
- UI status messaging during analysis/question generation and setup-screen fallback notices.
- AVSpeechSynthesizer playback for interviewer questions during the session's speaking phase.
- SpeechAnalyzer/SpeechTranscriber transcription for spoken user answers, with `SFSpeechRecognizer` fallback when SpeechAnalyzer assets are unavailable.
- AVAudioEngine microphone capture with route stabilization and audio conversion for SpeechAnalyzer.
- Silence-based turn taking: after 3 seconds of no transcript activity, the app enters a paused warning state; after 3 more seconds, it stops transcription and moves to transcript confirmation.
- A `Done Answering` action that lets users stop answer capture without waiting for silence finalization.
- A `.confirm` phase where the stopped transcript is editable before the answer is submitted for follow-up analysis.
- Full-answer transcript preservation across `.listening`, `.paused`, and `.confirm`, so Foundation Models receives the user-confirmed answer for the current turn.
- Foundation Models follow-up decisions from the confirmed answer transcript, bounded to one follow-up per primary question.
- `InterviewAnswer` history for each primary question, including optional generated follow-up questions and follow-up transcripts.
- Foundation Models final feedback generation from the confirmed job profile, generated questions, and bounded answer history.
- A deterministic mock feedback fallback when Foundation Models is unavailable, not linked, or fails feedback generation.

The app still does not implement:
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
18. If transcript activity stops for 3 seconds, the app enters `.paused`; if the user resumes speaking, it returns to `.listening`; if silence continues for 3 more seconds, it stops transcription and enters `.confirm`.
19. The user can also tap `Done Answering` to stop answer capture and move to `.confirm` without waiting for silence finalization.
20. During `.confirm`, `InterviewSessionView` shows an editable transcript review card backed by `editableTranscript`.
21. `Submit Answer` copies the edited transcript into the current answer buffer and moves to `.processing`.
22. During `.processing`, `AnswerFollowUpService` sends the confirmed answer transcript to Foundation Models to decide whether one follow-up is needed.
23. If a follow-up is needed, `generatedFollowUpQuestion` is spoken aloud; otherwise the app records an `InterviewAnswer` and advances to the next primary question.
24. Follow-up answers complete the existing `InterviewAnswer`, move to the next primary question, and do not generate another follow-up.
25. When the interview finishes, `InterviewFeedbackService` generates structured feedback from the confirmed job profile, generated questions, and bounded answer history.
26. If feedback generation fails, `MockInterviewFeedbackService` supplies `MockHirelogueData.feedback` and `feedbackGenerationErrorMessage` is shown on the feedback screen.
27. After feedback exists, the view model sets `shouldShowFeedback = true`.
28. `InterviewSessionView` calls `onShowFeedback`, and `ContentView` navigates to `.feedback`.
29. `InterviewFeedbackView` renders `viewModel.feedback`.

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
  - Shows an editable transcript confirmation card during `.confirm` before answer processing begins.
  - Shows final feedback-generation progress before navigating to the feedback screen.
  - Provides prototype demo controls for jumping between phases.
  - Confirms before ending the interview.

- `InterviewFeedbackView.swift`
  - Shows structured generated or fallback feedback.
  - Includes summary, competencies, strengths, improvements, STAR structure, technical reasoning, improved answer, and practice areas.
  - Shows a fallback notice when Foundation Models feedback generation fails.
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
  - Owns job input, extracted profile, generated questions, configuration, permission state, interview state, timers, answer history, completion state, and generated/fallback feedback.
  - Calls `JobAnalysisService` for job-profile extraction and falls back to mock data when needed.
  - Calls `InterviewQuestionService` for primary question generation from the edited profile.
  - Calls `SpeechSynthesisService` during `.speaking` to ask questions aloud.
  - Calls `SpeechTranscriptionService` during `.listening` and `.paused` to capture the user's answer.
  - Copies stopped answer transcripts into `editableTranscript` during `.confirm` so the user can correct transcription before submission.
  - Sends the confirmed answer transcript to Foundation Models during `.processing`.
  - Calls `AnswerFollowUpService` to decide whether one generated follow-up should be asked.
  - Records each submitted primary answer and optional follow-up answer in `answerHistory`.
  - Calls `InterviewFeedbackService` after the interview finishes and falls back to mock feedback when needed.
  - Owns silence-based transition logic, the `Done Answering` action, transcript confirmation, and feedback navigation.
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

- `InterviewFeedbackService.swift`
  - Defines `InterviewFeedbackService`.
  - Implements `FoundationModelInterviewFeedbackService` for final structured feedback generation from the confirmed job profile, generated questions, and captured `InterviewAnswer` history.
  - Uses guided generation to produce the existing `InterviewFeedback` payload in one bounded prompt.
  - Compacts job-profile fields and answer transcripts before prompting so the request stays within the on-device model context.
  - Sanitizes generated text so punctuation-only fragments are not rendered as feedback rows.
  - Implements `MockInterviewFeedbackService` as a deterministic fallback.

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
  - Session phases: speaking, listening, paused, confirm, processing, finished.
  - Provides user-facing title, instruction, and status text.

- `JobProfile.swift`
  - Mock extracted job analysis output.
  - Contains position, seniority, responsibilities, qualifications, and competencies.

- `InterviewQuestion.swift`
  - A planned or generated interview question.
  - Includes kind, prompt text, competency, and optional fallback follow-up.

- `InterviewAnswer.swift`
  - Captures the submitted transcript for one primary question.
  - Stores question identity, kind, competency, question text, primary transcript, and optional follow-up question/transcript.

- `CompetencyAssessment.swift`
  - Feedback tag model with a competency name and assessment note.

- `FeedbackPoint.swift`
  - Reusable feedback item for strengths and improvement areas.

- `STARAssessment.swift`
  - One part of STAR feedback: Situation, Task, Action, or Result.

- `InterviewFeedback.swift`
  - Full structured feedback payload shown after the interview.

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
- Do not add scoring beyond the current structured practice feedback unless the milestone explicitly asks for it.
- The live transcript is currently visible only because it was explicitly requested for transcription validation.
- Keep transcript editing limited to the `.confirm` phase after transcription has stopped, so live transcription updates do not race with user edits.
- Prefer adding service types before expanding `InterviewSessionViewModel` too much.
- Keep `InterviewSessionViewModel` as the single source of truth until there is a real reason to split it.
- Preserve the app's simple linear navigation flow unless the product scope changes.
- Build after changes with Xcode.

## Service Boundaries

Current services:

```text
Services/
  AnswerFollowUpService.swift
  InterviewFeedbackService.swift
  InterviewQuestionService.swift
  JobAnalysisService.swift
  SpeechSynthesisService.swift
  SpeechTranscriptionService.swift
```

Suggested future service boundaries:

```text
Services/
  MicrophonePermissionService.swift
  AnswerAnalysisService.swift
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
8. Confirm the live transcript moves to `.confirm` and can be edited before `Submit Answer`.
9. Confirm the transcript sent to follow-up analysis matches the edited confirmation transcript.
10. Confirm follow-up generation remains bounded to one follow-up per primary question.
11. Confirm answer history includes primary transcripts and generated follow-up transcripts when present.
12. Confirm final feedback generation uses `InterviewFeedbackService` and falls back to mock feedback when Foundation Models is unavailable.
