import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var sttProvider: STTProvider
    @Published var llmProvider: LLMProvider

    @Published var llmBaseURL: String
    @Published var llmModel: String
    @Published var llmAPIKey: String

    @Published var ollamaBaseURL: String
    @Published var ollamaModel: String
    @Published var ollamaAutoSetup: Bool
    @Published var ollamaStatus = "Local model has not been prepared yet."
    @Published var isPreparingOllama = false

    @Published var whisperBaseURL: String
    @Published var whisperModel: String
    @Published var whisperAPIKey: String

    @Published var enableFn: Bool
    @Published var appleSpeechFallback: Bool

    @Published var personaRewriteEnabled: Bool
    @Published var personas: [PersonaProfile]
    @Published var selectedPersonaID: UUID?
    @Published private(set) var activePersonaID: String

    @Published var customHotkeys: [HotkeyBinding]

    let errorLogStore = ErrorLogStore.shared

    private let settingsStore: SettingsStore
    private let modelManager: OllamaLocalModelManager

    init(
        settingsStore: SettingsStore,
        modelManager: OllamaLocalModelManager = OllamaLocalModelManager()
    ) {
        self.settingsStore = settingsStore
        self.modelManager = modelManager

        let currentPersonas = settingsStore.personas

        sttProvider = settingsStore.sttProvider
        llmProvider = settingsStore.llmProvider
        llmBaseURL = settingsStore.llmBaseURL
        llmModel = settingsStore.llmModel
        llmAPIKey = settingsStore.llmAPIKey
        ollamaBaseURL = settingsStore.ollamaBaseURL
        ollamaModel = settingsStore.ollamaModel
        ollamaAutoSetup = settingsStore.ollamaAutoSetup
        whisperBaseURL = settingsStore.whisperBaseURL
        whisperModel = settingsStore.whisperModel
        whisperAPIKey = settingsStore.whisperAPIKey
        enableFn = settingsStore.enableFnHotkey
        appleSpeechFallback = settingsStore.useAppleSpeechFallback
        personaRewriteEnabled = settingsStore.personaRewriteEnabled
        personas = currentPersonas
        selectedPersonaID = settingsStore.activePersona.map(\.id) ?? currentPersonas.first?.id
        activePersonaID = settingsStore.activePersonaID
        customHotkeys = settingsStore.customHotkeys
    }

    var selectedPersona: PersonaProfile? {
        guard let selectedPersonaID else { return nil }
        return personas.first { $0.id == selectedPersonaID }
    }

    var selectedPersonaName: String {
        get { selectedPersona?.name ?? "" }
        set {
            guard let persona = selectedPersona else { return }
            updateSelectedPersona(name: newValue, prompt: persona.prompt)
        }
    }

    var selectedPersonaPrompt: String {
        get { selectedPersona?.prompt ?? "" }
        set {
            guard let persona = selectedPersona else { return }
            updateSelectedPersona(name: persona.name, prompt: newValue)
        }
    }

    func setSTTProvider(_ provider: STTProvider) {
        sttProvider = provider
        settingsStore.sttProvider = provider
    }

    func setLLMProvider(_ provider: LLMProvider) {
        llmProvider = provider
        settingsStore.llmProvider = provider
    }

    func setLLMBaseURL(_ value: String) {
        llmBaseURL = value
        settingsStore.llmBaseURL = value
    }

    func setLLMModel(_ value: String) {
        llmModel = value
        settingsStore.llmModel = value
    }

    func setLLMAPIKey(_ value: String) {
        llmAPIKey = value
        settingsStore.llmAPIKey = value
    }

    func setOllamaBaseURL(_ value: String) {
        ollamaBaseURL = value
        settingsStore.ollamaBaseURL = value
    }

    func setOllamaModel(_ value: String) {
        ollamaModel = value
        settingsStore.ollamaModel = value
    }

    func setOllamaAutoSetup(_ value: Bool) {
        ollamaAutoSetup = value
        settingsStore.ollamaAutoSetup = value
    }

    func setWhisperBaseURL(_ value: String) {
        whisperBaseURL = value
        settingsStore.whisperBaseURL = value
    }

    func setWhisperModel(_ value: String) {
        whisperModel = value
        settingsStore.whisperModel = value
    }

    func setWhisperAPIKey(_ value: String) {
        whisperAPIKey = value
        settingsStore.whisperAPIKey = value
    }

    func setEnableFn(_ value: Bool) {
        enableFn = value
        settingsStore.enableFnHotkey = value
    }

    func setAppleSpeechFallback(_ value: Bool) {
        appleSpeechFallback = value
        settingsStore.useAppleSpeechFallback = value
    }

    func setPersonaRewriteEnabled(_ value: Bool) {
        personaRewriteEnabled = value
        settingsStore.personaRewriteEnabled = value
    }

    func selectPersona(_ id: UUID?) {
        selectedPersonaID = id
        if settingsStore.activePersonaID.isEmpty, let id {
            settingsStore.activePersonaID = id.uuidString
            activePersonaID = id.uuidString
        }
    }

    func addHotkey(_ binding: HotkeyBinding) {
        guard !customHotkeys.contains(where: { $0.keyCode == binding.keyCode && $0.modifierFlags == binding.modifierFlags }) else {
            return
        }

        customHotkeys.append(binding)
        settingsStore.customHotkeys = customHotkeys
    }

    func removeHotkey(_ binding: HotkeyBinding) {
        customHotkeys.removeAll { $0.id == binding.id }
        settingsStore.customHotkeys = customHotkeys
    }

    func addPersona() {
        let persona = PersonaProfile(name: "新建人设", prompt: "请按这个人设风格重写文本。")
        personas.append(persona)
        persistPersonas()
        selectedPersonaID = persona.id

        if settingsStore.activePersonaID.isEmpty {
            settingsStore.activePersonaID = persona.id.uuidString
            activePersonaID = persona.id.uuidString
        }
    }

    func deleteSelectedPersona() {
        guard let selectedPersonaID else { return }
        personas.removeAll { $0.id == selectedPersonaID }
        persistPersonas()

        if settingsStore.activePersonaID == selectedPersonaID.uuidString {
            settingsStore.activePersonaID = personas.first?.id.uuidString ?? ""
            activePersonaID = settingsStore.activePersonaID
        }

        self.selectedPersonaID = personas.first?.id
    }

    func activateSelectedPersona() {
        guard let selectedPersona else { return }
        settingsStore.activePersonaID = selectedPersona.id.uuidString
        activePersonaID = selectedPersona.id.uuidString
        if !personaRewriteEnabled {
            setPersonaRewriteEnabled(true)
        }
        objectWillChange.send()
    }

    func deactivatePersonaRewrite() {
        setPersonaRewriteEnabled(false)
    }

    func updateSelectedPersona(name: String, prompt: String) {
        guard let selectedPersonaID, let index = personas.firstIndex(where: { $0.id == selectedPersonaID }) else { return }
        personas[index].name = name
        personas[index].prompt = prompt
        persistPersonas()
    }

    func prepareOllamaModel() {
        guard !isPreparingOllama else { return }

        isPreparingOllama = true
        ollamaStatus = "Preparing local model..."

        settingsStore.ollamaBaseURL = ollamaBaseURL
        settingsStore.ollamaModel = ollamaModel
        settingsStore.ollamaAutoSetup = ollamaAutoSetup

        Task {
            do {
                try await modelManager.ensureModelReady(settingsStore: settingsStore)
                ollamaStatus = "Local model is ready."
            } catch {
                ollamaStatus = "Failed: \(error.localizedDescription)"
            }

            isPreparingOllama = false
        }
    }

    private func persistPersonas() {
        settingsStore.personas = personas
        objectWillChange.send()
    }
}
