import Foundation

/// The simulated voice-interview state shown in the session screen.
enum InterviewPhase: String, CaseIterable, Identifiable {
    case speaking
    case listening
    case paused
    case processing
    case finished

    var id: String { rawValue }

    /// Primary label shown near the state indicator.
    var title: String {
        switch self {
        case .speaking: "Interviewer is speaking"
        case .listening: "Listening"
        case .paused: "Still answering?"
        case .processing: "Reviewing your answer"
        case .finished: "Interview complete"
        }
    }

    /// Short instruction that explains what the user should do in this phase.
    var instruction: String {
        switch self {
        case .speaking: "Listen to the question. Recording starts automatically in the finished app."
        case .listening: "Answer naturally. The interview continues when you finish."
        case .paused: "Continue speaking to keep answering."
        case .processing: "Preparing the next question."
        case .finished: "Preparing your feedback."
        }
    }

    /// Compact footer status shown below interview progress.
    var status: String {
        switch self {
        case .speaking: "Not listening yet"
        case .listening: "Microphone simulated"
        case .paused: "Waiting for you"
        case .processing: "Processing"
        case .finished: "Finishing up"
        }
    }
}
