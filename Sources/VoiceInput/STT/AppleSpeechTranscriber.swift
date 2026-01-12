import Foundation
import Speech

final class AppleSpeechTranscriber: Transcriber {
    func transcribe(audioFile: AudioFile) async throws -> String {
        // Must request authorization on main thread to avoid TCC crash
        let auth = await requestAuthorizationOnMainThread()
        guard auth == .authorized else {
            throw NSError(domain: "AppleSpeechTranscriber", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        
        // Create recognizer on main thread
        let recognizer: SFSpeechRecognizer? = await MainActor.run {
            SFSpeechRecognizer()
        }
        
        guard let recognizer else {
            throw NSError(domain: "AppleSpeechTranscriber", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        let request = SFSpeechURLRecognitionRequest(url: audioFile.fileURL)

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }
                if let error {
                    hasResumed = true
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    hasResumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func requestAuthorizationOnMainThread() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }
}
