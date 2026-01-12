import Foundation

final class DIContainer {
    let appState = AppStateStore()
    let settingsStore = SettingsStore()

    // These must be initialized immediately, not lazily
    let hotkeyService: HotkeyService
    let audioRecorder: AudioRecorder
    let overlayController: OverlayController
    let clipboard: ClipboardService
    let textInjector: TextInjector
    let historyStore: HistoryStore
    let llmService: LLMService
    let sttRouter: STTRouter

    init() {
        hotkeyService = EventTapHotkeyService(settingsStore: settingsStore)
        audioRecorder = AVFoundationAudioRecorder()
        overlayController = OverlayController(appState: appState)
        clipboard = SystemClipboardService()
        textInjector = AXTextInjector()
        historyStore = FileHistoryStore()
        llmService = OpenAICompatibleLLMService(settingsStore: settingsStore)
        sttRouter = STTRouter(
            settingsStore: settingsStore,
            whisper: WhisperAPITranscriber(settingsStore: settingsStore),
            appleSpeech: AppleSpeechTranscriber()
        )
    }
}
