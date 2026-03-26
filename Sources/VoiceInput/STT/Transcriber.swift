import Foundation

protocol Transcriber {
    func transcribe(audioFile: AudioFile) async throws -> String
}

final class STTRouter {
    private let settingsStore: SettingsStore
    private let whisper: Transcriber
    private let appleSpeech: Transcriber
    private let localModel: Transcriber

    init(settingsStore: SettingsStore, whisper: Transcriber, appleSpeech: Transcriber, localModel: Transcriber) {
        self.settingsStore = settingsStore
        self.whisper = whisper
        self.appleSpeech = appleSpeech
        self.localModel = localModel
    }

    func transcribe(audioFile: AudioFile) async throws -> String {
        switch settingsStore.sttProvider {
        case .whisperAPI:
            if !settingsStore.whisperBaseURL.isEmpty {
                do {
                    return try await whisper.transcribe(audioFile: audioFile)
                } catch {
                    NetworkDebugLogger.logError(context: "Remote STT failed", error: error)
                    if settingsStore.useAppleSpeechFallback {
                        NetworkDebugLogger.logMessage("Falling back to Apple Speech after remote STT failure")
                        return try await appleSpeech.transcribe(audioFile: audioFile)
                    }
                    throw error
                }
            }
            if settingsStore.useAppleSpeechFallback {
                NetworkDebugLogger.logMessage("Remote STT is not configured, using Apple Speech fallback")
                return try await appleSpeech.transcribe(audioFile: audioFile)
            }
            throw NSError(
                domain: "STTRouter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Remote transcription is not configured yet."]
            )

        case .appleSpeech:
            return try await appleSpeech.transcribe(audioFile: audioFile)

        case .localModel:
            do {
                return try await localModel.transcribe(audioFile: audioFile)
            } catch {
                NetworkDebugLogger.logError(context: "Local STT failed", error: error)
                if settingsStore.useAppleSpeechFallback {
                    NetworkDebugLogger.logMessage("Falling back to Apple Speech after local STT failure")
                    return try await appleSpeech.transcribe(audioFile: audioFile)
                }
                throw error
            }
        }
    }
}
