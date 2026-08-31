# Interview Practice Assistant — Core Project Scope

**Status:** Approved core scope  
**Date:** 19 August 2026  
**Estimated development period:** Approximately two weeks

## 1. Project Concept

The project is an English-language, real-time, turn-based voice interview simulator. The application analyzes a job opening supplied by the user, conducts an adaptive practice interview, and generates evidence-based feedback after the session.

The application is intended as a practice tool. Its feedback does not predict employability or the outcome of a real recruitment process.

## 2. Primary Apple Technologies

- **Foundation Models:** Extracts the job profile, prepares the interview plan, generates adaptive questions and follow-up questions, analyzes answers, and produces final feedback.
- **SpeechAnalyzer:** Manages speech analysis sessions and accepts audio input for speech modules.
- **SpeechTranscriber:** Transcribes the user's spoken answers internally during the interview.
- **SpeechDetector:** Planned voice activity detection refinement. The current implementation uses transcript activity timestamps and deterministic Swift thresholds for turn-taking.
- **AVSpeechSynthesizer:** Presents the AI interviewer's questions through spoken audio.
- **AVAudioEngine:** Captures microphone input for transcription.
- **SwiftUI:** Provides the application interface and represents the interview-session state.

## 3. Core User Flow

### 3.1 Interview Preparation

1. The user pastes the complete text of a job opening.
2. Foundation Models extracts a structured job profile containing:
   - Position
   - Responsibilities
   - Required qualifications
   - Preferred qualifications
   - Technical competencies
   - Behavioral competencies
   - Inferred seniority, when identifiable
3. The application shows the extracted profile for user review and confirmation.
4. The user chooses:
   - Interview duration
   - Interview type: technical, behavioral, or mixed
5. Foundation Models generates a structured interview plan based on the confirmed job profile.

The interview language is fixed to English. The application does not ask the user to choose a preferred language.

### 3.2 Interview Session

1. The AI interviewer introduces the session and asks a question aloud.
2. When the AI finishes speaking, the application automatically begins listening.
3. SpeechAnalyzer transcribes the user's answer, with `SFSpeechRecognizer` as a fallback if SpeechAnalyzer assets are unavailable.
4. The current prototype displays the live transcript during the interview only for development validation.
5. Transcript activity and silence thresholds determine when the user may have finished answering.
6. The user can tap `Done Answering` to stop answer capture without waiting for silence finalization.
7. After transcription stops, the user reviews and may edit the transcript before submitting the answer.
8. Foundation Models analyzes the confirmed full-answer transcript for follow-up needs.
9. The AI interviewer performs one of the following actions:
   - Asks one relevant follow-up question
   - Requests clarification
   - Moves to the next competency or planned question
10. The next question is presented aloud and the cycle continues until the interview ends.

### 3.3 Post-Interview Feedback

After the interview, the application generates structured feedback containing:

- Competencies assessed
- Strengths demonstrated
- Answers that lacked sufficient detail
- Technical-reasoning feedback
- Behavioral-answer structure, including STAR completeness where relevant
- Answer excerpts that support the feedback
- Specific improvement suggestions
- Stronger example formulations for selected answers
- Recommended areas to practise before the real interview

The internal transcript may support the feedback. The current prototype shows the live transcript during the interview for validation, but whether users can inspect the full transcript after the session is outside the currently confirmed core scope.

## 4. Conversation Model

The application uses automatically managed, turn-based voice interaction rather than simultaneous full-duplex conversation.

The core session states are:

1. **Preparing:** Analyze the job opening and create the interview plan.
2. **Speaking:** Present an interviewer question through speech synthesis.
3. **Listening:** Capture and transcribe the user's answer.
4. **Paused:** Wait briefly to distinguish a natural pause from the end of an answer.
5. **Confirm:** Stop transcription and let the user edit the captured transcript before submission.
6. **Processing:** Analyze the confirmed answer and determine the next interview action.
7. **Finished:** End the interview and generate final feedback.

A 3-second silence threshold moves the session from **Listening** to **Paused**. If the user resumes speaking, the countdown is cancelled and the session returns to **Listening**. If silence continues for 3 more seconds, transcription stops and the answer moves to **Confirm**. The user can also tap **Done Answering** to move to **Confirm** immediately. Processing begins only after the user submits the confirmed transcript.

## 5. Responsibility Boundaries

### Deterministic Swift Logic Controls

- Interview duration
- Maximum number of primary questions
- Maximum number of follow-up questions
- Required competency coverage
- Session-state transitions
- Transcript confirmation before answer processing
- Speech and silence thresholds
- Audio capture and playback
- Error, cancellation, and availability handling

### Foundation Models Controls

- Job-profile extraction
- Interview-plan content
- Question wording
- Contextual follow-up wording
- Answer analysis
- Final feedback generation

This separation keeps the interview bounded and predictable while still allowing AI-driven adaptation.

## 6. Initial Product Constraints

- English interviews only
- Maximum of five primary questions
- Maximum of one follow-up per primary question
- Automatic turn-taking through speech and silence detection
- Temporary live transcript display is allowed during development validation
- Transcript editing is allowed only after answer capture stops and before submission
- No interruption while the AI interviewer is speaking
- No video or camera analysis
- No facial-expression, emotion, accent, or voice-confidence scoring
- No resume analysis
- No external company research
- No prediction of hiring success
- No requirement for simultaneous, fully interruptible voice conversation

## 7. Out of Scope and Potential Future Work

The following features are excluded from the two-week core scope:

- Allowing the user to interrupt the AI while it is speaking
- Full-duplex or simultaneous voice conversation
- Resume or professional-profile integration
- External research about the hiring company
- Video-based interview analysis
- Emotion or confidence detection
- Multiple interview languages
- Sharing or exporting interview results
- Persistent interview history
- Full post-interview transcript review

These features may be reconsidered only after the complete core workflow is implemented and validated.

## 8. Core Success Criteria

The core project is successful when a user can:

1. Paste a job opening and confirm an accurately extracted job profile.
2. Begin an English voice interview based on that profile.
3. Answer questions naturally without manually controlling recording for every turn.
4. Complete an automatically managed interview of bounded length.
5. Receive structured feedback grounded in their interview answers and the qualifications from the job opening.

## 9. Reference Documentation

- [Foundation Models — Apple Developer Documentation](https://developer.apple.com/documentation/foundationmodels)
- [SpeechAnalyzer — Apple Developer Documentation](https://developer.apple.com/documentation/speech/speechanalyzer)
- [SpeechDetector — Apple Developer Documentation](https://developer.apple.com/documentation/speech/speechdetector)
- [AVSpeechSynthesizer — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)
- [Bring advanced speech-to-text to your app with SpeechAnalyzer — WWDC25](https://developer.apple.com/videos/play/wwdc2025/277/)
