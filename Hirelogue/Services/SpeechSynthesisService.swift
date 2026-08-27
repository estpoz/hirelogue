import AVFAudio
import Foundation

// MARK: - Service Contract

/// Speaks interviewer text aloud while keeping AVSpeechSynthesizer details outside the view model.
@MainActor
protocol SpeechSynthesisService: AnyObject {
    func speak(_ text: String) async
    func stopSpeaking()
}

// MARK: - AVSpeechSynthesizer Implementation

/// Uses the system speech synthesizer to make the interviewer ask questions verbally.
@MainActor
final class InterviewSpeechSynthesisService: NSObject, SpeechSynthesisService {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks one utterance and resumes only after speech finishes or is cancelled.
    func speak(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        stopSpeaking()
        configureAudioSession()

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance(for: trimmedText))
        }
    }

    /// Stops current speech immediately and releases any task waiting for completion.
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishCurrentUtteranceIfNeeded()
    }

    /// Configures playback for spoken interviewer prompts without introducing recording yet.
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? audioSession.setActive(true)
    }

    /// Builds a consistent English utterance for the interviewer voice.
    private func utterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        return utterance
    }

    private func finishCurrentUtteranceIfNeeded() {
        continuation?.resume()
        continuation = nil
    }
}

// MARK: - Speech Delegate

extension InterviewSpeechSynthesisService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            finishCurrentUtteranceIfNeeded()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            finishCurrentUtteranceIfNeeded()
        }
    }
}
