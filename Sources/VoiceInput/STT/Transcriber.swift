import Foundation

protocol Transcriber {
    func transcribe(audioFile: AudioFile) async throws -> String
}

final class STTRouter {
    private let settingsStore: SettingsStore
    private let whisper: Transcriber
    private let appleSpeech: Transcriber

    init(settingsStore: SettingsStore, whisper: Transcriber, appleSpeech: Transcriber) {
        self.settingsStore = settingsStore
        self.whisper = whisper
        self.appleSpeech = appleSpeech
    }

    func transcribe(audioFile: AudioFile) async throws -> String {
        switch settingsStore.sttProvider {
        case .whisperAPI:
            if !settingsStore.whisperBaseURL.isEmpty {
                do {
                    return try await whisper.transcribe(audioFile: audioFile)
                } catch {
                    return try await appleSpeech.transcribe(audioFile: audioFile)
                }
            }
            return try await appleSpeech.transcribe(audioFile: audioFile)

        case .appleSpeech:
            return try await appleSpeech.transcribe(audioFile: audioFile)
        }
    }
}
