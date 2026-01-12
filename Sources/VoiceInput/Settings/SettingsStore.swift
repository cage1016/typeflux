import Foundation

final class SettingsStore {
    private let defaults = UserDefaults.standard

    var llmBaseURL: String {
        get { defaults.string(forKey: "llm.baseURL") ?? "" }
        set { defaults.set(newValue, forKey: "llm.baseURL") }
    }

    var llmModel: String {
        get { defaults.string(forKey: "llm.model") ?? "" }
        set { defaults.set(newValue, forKey: "llm.model") }
    }

    var llmAPIKey: String {
        get { defaults.string(forKey: "llm.apiKey") ?? "" }
        set { defaults.set(newValue, forKey: "llm.apiKey") }
    }

    var whisperBaseURL: String {
        get { defaults.string(forKey: "stt.whisper.baseURL") ?? "" }
        set { defaults.set(newValue, forKey: "stt.whisper.baseURL") }
    }

    var whisperModel: String {
        get { defaults.string(forKey: "stt.whisper.model") ?? "" }
        set { defaults.set(newValue, forKey: "stt.whisper.model") }
    }

    var whisperAPIKey: String {
        get { defaults.string(forKey: "stt.whisper.apiKey") ?? "" }
        set { defaults.set(newValue, forKey: "stt.whisper.apiKey") }
    }

    var useAppleSpeechFallback: Bool {
        get { defaults.object(forKey: "stt.appleSpeech.enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "stt.appleSpeech.enabled") }
    }

    var enableFnHotkey: Bool {
        get { defaults.object(forKey: "hotkey.fn.enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hotkey.fn.enabled") }
    }

    var customHotkeyJSON: String {
        get { defaults.string(forKey: "hotkey.custom.json") ?? "[]" }
        set { defaults.set(newValue, forKey: "hotkey.custom.json") }
    }

    var customHotkeys: [HotkeyBinding] {
        get {
            guard let data = customHotkeyJSON.data(using: .utf8) else { return defaultHotkeys }
            let decoded = (try? JSONDecoder().decode([HotkeyBinding].self, from: data)) ?? []
            return decoded.isEmpty ? defaultHotkeys : decoded
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
            customHotkeyJSON = String(decoding: data, as: UTF8.self)
        }
    }

    // Default hotkey: Option+Space (keyCode 49 = Space, Option = 0x80000)
    private var defaultHotkeys: [HotkeyBinding] {
        [HotkeyBinding(keyCode: 49, modifierFlags: 0x80000)]
    }
}
