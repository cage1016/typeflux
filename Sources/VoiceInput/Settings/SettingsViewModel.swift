import AppKit
import Foundation
import SwiftUI

@MainActor
final class StudioViewModel: ObservableObject {
    @Published var currentSection: StudioSection
    @Published var searchQuery = ""
    @Published var modelDomain: StudioModelDomain = .stt
    @Published var focusedModelProvider: StudioModelProviderID

    @Published var sttProvider: STTProvider
    @Published var llmProvider: LLMProvider
    @Published var appearanceMode: AppearanceMode

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
    @Published private(set) var historyRecords: [HistoryRecord]
    @Published var toastMessage: String?

    let errorLogStore = ErrorLogStore.shared

    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore
    private let modelManager: OllamaLocalModelManager

    init(
        settingsStore: SettingsStore,
        historyStore: HistoryStore,
        initialSection: StudioSection,
        modelManager: OllamaLocalModelManager = OllamaLocalModelManager()
    ) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.modelManager = modelManager

        let currentPersonas = settingsStore.personas

        currentSection = initialSection
        sttProvider = settingsStore.sttProvider
        llmProvider = settingsStore.llmProvider
        focusedModelProvider = settingsStore.sttProvider == .appleSpeech ? .appleSpeech : .whisperAPI
        appearanceMode = settingsStore.appearanceMode
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
        historyRecords = historyStore.list()
    }

    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayedHistory: [HistoryPresentationRecord] {
        filteredHistory.map(makeHistoryPresentation)
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

    var filteredPersonas: [PersonaProfile] {
        guard !searchQuery.isEmpty else { return personas }
        return personas.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.prompt.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var transcriptionMinutesText: String {
        let minutes = historyRecords.count * 3 + historyRecords.reduce(0) { $0 + min($1.text.count / 80, 12) }
        return NumberFormatter.localizedString(from: NSNumber(value: minutes), number: .decimal)
    }

    var completedTranscriptionsText: String {
        NumberFormatter.localizedString(from: NSNumber(value: historyRecords.count), number: .decimal)
    }

    var architectureCards: [StudioModelCard] {
        switch modelDomain {
        case .stt:
            return [
                StudioModelCard(
                    id: "apple-speech",
                    name: "Apple Speech",
                    summary: "On-device system recognizer for low-friction local transcription.",
                    badge: "Local",
                    metadata: "Built-in • Offline friendly",
                    isSelected: sttProvider == .appleSpeech,
                    isMuted: false,
                    actionTitle: sttProvider == .appleSpeech ? "Selected" : "Use Local"
                ),
                StudioModelCard(
                    id: "whisper-api",
                    name: "Whisper API",
                    summary: "Cloud or gateway-backed transcription using OpenAI-compatible APIs.",
                    badge: "Remote",
                    metadata: whisperModel.isEmpty ? "Model not set" : whisperModel,
                    isSelected: sttProvider == .whisperAPI,
                    isMuted: false,
                    actionTitle: sttProvider == .whisperAPI ? "Selected" : "Use Remote"
                )
            ]

        case .llm:
            return [
                StudioModelCard(
                    id: "ollama-local",
                    name: "Local Ollama",
                    summary: "Runs rewritten output locally with automatic model preparation.",
                    badge: "Local",
                    metadata: ollamaModel,
                    isSelected: llmProvider == .ollama,
                    isMuted: false,
                    actionTitle: llmProvider == .ollama ? "Selected" : "Use Local"
                ),
                StudioModelCard(
                    id: "openai-compatible",
                    name: "OpenAI-Compatible",
                    summary: "Use remote chat endpoints for persona rewriting and editing.",
                    badge: "Remote",
                    metadata: llmModel.isEmpty ? "Model not set" : llmModel,
                    isSelected: llmProvider == .openAICompatible,
                    isMuted: false,
                    actionTitle: llmProvider == .openAICompatible ? "Selected" : "Use Remote"
                )
            ]
        }
    }

    var currentArchitectureTitle: String {
        switch modelDomain {
        case .stt:
            return sttProvider == .appleSpeech ? "Local Processing" : "Remote API"
        case .llm:
            return llmProvider == .ollama ? "Local Processing" : "Remote API"
        }
    }

    var currentArchitectureDescription: String {
        switch modelDomain {
        case .stt:
            return sttProvider == .appleSpeech ? "Using on-device speech recognition." : "Using OpenAI-compatible transcription services."
        case .llm:
            return llmProvider == .ollama ? "Using local Ollama generation." : "Using remote chat-completion endpoints."
        }
    }

    func navigate(to section: StudioSection) {
        currentSection = section
        searchQuery = ""
        refreshHistory()
    }

    func refreshHistory() {
        historyRecords = historyStore.list()
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        settingsStore.appearanceMode = mode
    }

    func setSTTProvider(_ provider: STTProvider) {
        sttProvider = provider
        settingsStore.sttProvider = provider
        focusedModelProvider = provider == .appleSpeech ? .appleSpeech : .whisperAPI
    }

    func setLLMProvider(_ provider: LLMProvider) {
        llmProvider = provider
        settingsStore.llmProvider = provider
        focusedModelProvider = provider == .ollama ? .ollama : .openAICompatible
    }

    func setSTTModelSelection(_ provider: STTProvider, suggestedModel: String) {
        setSTTProvider(provider)
        if provider == .whisperAPI {
            whisperModel = suggestedModel
            settingsStore.whisperModel = suggestedModel
        }
    }

    func setLLMModelSelection(_ provider: LLMProvider, suggestedModel: String) {
        setLLMProvider(provider)
        switch provider {
        case .ollama:
            ollamaModel = suggestedModel
            settingsStore.ollamaModel = suggestedModel
        case .openAICompatible:
            llmModel = suggestedModel
            settingsStore.llmModel = suggestedModel
        }
    }

    func setModelDomain(_ domain: StudioModelDomain) {
        modelDomain = domain
        focusedModelProvider = activeProvider(for: domain)
    }

    func focusModelProvider(_ provider: StudioModelProviderID) {
        guard provider.domain == modelDomain else { return }
        focusedModelProvider = provider
    }

    func setLLMBaseURL(_ value: String) { llmBaseURL = value; settingsStore.llmBaseURL = value }
    func setLLMModel(_ value: String) { llmModel = value; settingsStore.llmModel = value }
    func setLLMAPIKey(_ value: String) { llmAPIKey = value; settingsStore.llmAPIKey = value }
    func setOllamaBaseURL(_ value: String) { ollamaBaseURL = value; settingsStore.ollamaBaseURL = value }
    func setOllamaModel(_ value: String) { ollamaModel = value; settingsStore.ollamaModel = value }
    func setOllamaAutoSetup(_ value: Bool) { ollamaAutoSetup = value; settingsStore.ollamaAutoSetup = value }
    func setWhisperBaseURL(_ value: String) { whisperBaseURL = value; settingsStore.whisperBaseURL = value }
    func setWhisperModel(_ value: String) { whisperModel = value; settingsStore.whisperModel = value }
    func setWhisperAPIKey(_ value: String) { whisperAPIKey = value; settingsStore.whisperAPIKey = value }
    func setEnableFn(_ value: Bool) { enableFn = value; settingsStore.enableFnHotkey = value }
    func setAppleSpeechFallback(_ value: Bool) { appleSpeechFallback = value; settingsStore.useAppleSpeechFallback = value }
    func setPersonaRewriteEnabled(_ value: Bool) { personaRewriteEnabled = value; settingsStore.personaRewriteEnabled = value }

    func selectPersona(_ id: UUID?) {
        selectedPersonaID = id
        if settingsStore.activePersonaID.isEmpty, let id {
            settingsStore.activePersonaID = id.uuidString
            activePersonaID = id.uuidString
        }
    }

    func addHotkey(_ binding: HotkeyBinding) {
        guard !customHotkeys.contains(where: { $0.keyCode == binding.keyCode && $0.modifierFlags == binding.modifierFlags }) else { return }
        customHotkeys.append(binding)
        settingsStore.customHotkeys = customHotkeys
    }

    func removeHotkey(_ binding: HotkeyBinding) {
        customHotkeys.removeAll { $0.id == binding.id }
        settingsStore.customHotkeys = customHotkeys
    }

    func addPersona() {
        let persona = PersonaProfile(name: "New Persona", prompt: "Describe the desired voice, tone, and output structure here.")
        personas.insert(persona, at: 0)
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
                showToast("Local model is ready.")
            } catch {
                ollamaStatus = "Failed: \(error.localizedDescription)"
                showToast("Local model preparation failed.")
            }
            isPreparingOllama = false
        }
    }

    func exportHistory() {
        do {
            let url = try historyStore.exportMarkdown()
            NSWorkspace.shared.activateFileViewerSelecting([url])
            showToast("History exported.")
        } catch {
            showToast("Failed to export history.")
        }
    }

    func clearHistory() {
        historyStore.clear()
        refreshHistory()
        showToast("History cleared.")
    }

    func applyModelConfiguration() {
        showToast("Configuration saved.")
    }

    func dismissToast() {
        toastMessage = nil
    }

    private var filteredHistory: [HistoryRecord] {
        guard !searchQuery.isEmpty else { return historyRecords }
        return historyRecords.filter {
            $0.text.localizedCaseInsensitiveContains(searchQuery) ||
            URL(fileURLWithPath: $0.audioFilePath).lastPathComponent.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private func persistPersonas() {
        settingsStore.personas = personas
    }

    private func activeProvider(for domain: StudioModelDomain) -> StudioModelProviderID {
        switch domain {
        case .stt:
            return sttProvider == .appleSpeech ? .appleSpeech : .whisperAPI
        case .llm:
            return llmProvider == .ollama ? .ollama : .openAICompatible
        }
    }

    private func showToast(_ text: String) {
        toastMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastMessage == text {
                toastMessage = nil
            }
        }
    }

    private func makeHistoryPresentation(_ record: HistoryRecord) -> HistoryPresentationRecord {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let fileName = URL(fileURLWithPath: record.audioFilePath).lastPathComponent
        let preview = record.text.replacingOccurrences(of: "\n", with: " ")

        let fileExtension = URL(fileURLWithPath: record.audioFilePath).pathExtension.lowercased()
        let iconData: (String, String)
        switch fileExtension {
        case "wav":
            iconData = ("mic.fill", "purple")
        case "mp4":
            iconData = ("play.rectangle.fill", "green")
        case "m4a":
            iconData = ("waveform", "orange")
        default:
            iconData = ("doc.text.fill", "blue")
        }

        return HistoryPresentationRecord(
            id: record.id,
            timestampText: formatter.string(from: record.date),
            sourceName: fileName,
            previewText: "“\(preview.prefix(84))\(preview.count > 84 ? "..." : "")”",
            accentName: iconData.0,
            accentColorName: iconData.1
        )
    }
}
