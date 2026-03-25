import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @StateObject private var recorder = HotkeyRecorder()

    var body: some View {
        TabView {
            HotkeySettingsTab(viewModel: viewModel, recorder: recorder)
                .tabItem { Text("Hotkey") }
            STTSettingsTab(viewModel: viewModel)
                .tabItem { Text("STT") }
            LLMSettingsTab(viewModel: viewModel)
                .tabItem { Text("LLM") }
            PersonaSettingsTab(viewModel: viewModel)
                .tabItem { Text("Personas") }
            ErrorLogSettingsTab(errorLogStore: viewModel.errorLogStore)
                .tabItem {
                    HStack {
                        Text("Errors")
                        if !viewModel.errorLogStore.entries.isEmpty {
                            Text("(\(viewModel.errorLogStore.entries.count))")
                                .foregroundColor(.red)
                        }
                    }
                }
        }
        .padding(14)
        .frame(minWidth: 760, minHeight: 620)
    }
}

private struct HotkeySettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var recorder: HotkeyRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hotkey")
                .font(.title2)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(
                        "Enable Right Command (press-and-hold, temporary debug override)",
                        isOn: Binding(
                            get: { viewModel.enableFn },
                            set: viewModel.setEnableFn
                        )
                    )

                    HStack {
                        Button(recorder.isRecording ? "Recording…" : "Add Custom Hotkey") {
                            if recorder.isRecording {
                                recorder.stop()
                            } else {
                                recorder.start { binding in
                                    viewModel.addHotkey(binding)
                                }
                            }
                        }

                        Text("Press a key with modifiers (⌘/⌥/⌃/⇧) to record")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.customHotkeys.isEmpty {
                        Text("No custom hotkeys yet")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        List {
                            ForEach(viewModel.customHotkeys) { binding in
                                HStack {
                                    Text(HotkeyFormat.display(binding))
                                    Spacer()
                                    Button("Remove") {
                                        viewModel.removeHotkey(binding)
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }
                .padding(6)
            } label: {
                Text("Bindings")
            }

            Spacer()
        }
    }
}

private struct STTSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Speech To Text")
                    .font(.title2)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(
                            "Provider",
                            selection: Binding(
                                get: { viewModel.sttProvider },
                                set: viewModel.setSTTProvider
                            )
                        ) {
                            ForEach(STTProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle(
                            "Enable Apple Speech fallback when Whisper is unavailable",
                            isOn: Binding(
                                get: { viewModel.appleSpeechFallback },
                                set: viewModel.setAppleSpeechFallback
                            )
                        )
                    }
                    .padding(6)
                } label: {
                    Text("Provider")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(
                            "Whisper Base URL",
                            text: Binding(
                                get: { viewModel.whisperBaseURL },
                                set: viewModel.setWhisperBaseURL
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        TextField(
                            "Whisper Model",
                            text: Binding(
                                get: { viewModel.whisperModel },
                                set: viewModel.setWhisperModel
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        SecureField(
                            "Whisper API Key (optional for local gateway)",
                            text: Binding(
                                get: { viewModel.whisperAPIKey },
                                set: viewModel.setWhisperAPIKey
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Text("Use this for OpenAI Whisper or any OpenAI-compatible transcription service.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                } label: {
                    Text("Whisper / OpenAI-Compatible")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple Speech runs on-device and is useful as a local fallback or a primary offline-ish option.")
                            .font(.callout)
                        Text("If you pick Apple Speech as the STT provider, the app will skip Whisper and transcribe locally.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                } label: {
                    Text("Apple Speech")
                }
            }
        }
    }
}

private struct LLMSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("LLM")
                    .font(.title2)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(
                            "Provider",
                            selection: Binding(
                                get: { viewModel.llmProvider },
                                set: viewModel.setLLMProvider
                            )
                        ) {
                            ForEach(LLMProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Persona rewriting and voice-driven editing will use the selected provider.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                } label: {
                    Text("Provider")
                }

                if viewModel.llmProvider == .openAICompatible {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(
                                "Base URL",
                                text: Binding(
                                    get: { viewModel.llmBaseURL },
                                    set: viewModel.setLLMBaseURL
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            TextField(
                                "Model",
                                text: Binding(
                                    get: { viewModel.llmModel },
                                    set: viewModel.setLLMModel
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            SecureField(
                                "API Key (optional for local gateways)",
                                text: Binding(
                                    get: { viewModel.llmAPIKey },
                                    set: viewModel.setLLMAPIKey
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                        .padding(6)
                    } label: {
                        Text("OpenAI-Compatible Chat")
                    }
                } else {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(
                                "Ollama Base URL",
                                text: Binding(
                                    get: { viewModel.ollamaBaseURL },
                                    set: viewModel.setOllamaBaseURL
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            TextField(
                                "Local Model",
                                text: Binding(
                                    get: { viewModel.ollamaModel },
                                    set: viewModel.setOllamaModel
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            Toggle(
                                "Automatically install/start Ollama and pull the model",
                                isOn: Binding(
                                    get: { viewModel.ollamaAutoSetup },
                                    set: viewModel.setOllamaAutoSetup
                                )
                            )

                            HStack {
                                Button(viewModel.isPreparingOllama ? "Preparing…" : "Prepare Local Model") {
                                    viewModel.prepareOllamaModel()
                                }
                                .disabled(viewModel.isPreparingOllama)

                                Text(viewModel.ollamaStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(6)
                    } label: {
                        Text("Local Ollama")
                    }
                }
            }
        }
    }
}

private struct PersonaSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(
                    "Enable persona-based rewriting",
                    isOn: Binding(
                        get: { viewModel.personaRewriteEnabled },
                        set: viewModel.setPersonaRewriteEnabled
                    )
                )

                HStack {
                    Button("Add Persona") {
                        viewModel.addPersona()
                    }

                    Button("Delete") {
                        viewModel.deleteSelectedPersona()
                    }
                    .disabled(viewModel.selectedPersona == nil)
                }

                List(
                    selection: Binding(
                        get: { viewModel.selectedPersonaID },
                        set: viewModel.selectPersona
                    )
                ) {
                    ForEach(viewModel.personas) { persona in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(persona.name)
                                Text(persona.prompt)
                                    .lineLimit(2)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if persona.id.uuidString == viewModel.activePersonaID {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .tag(Optional(persona.id))
                    }
                }
            }
            .frame(minWidth: 250)
            .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Persona Editor")
                    .font(.title3)

                if viewModel.selectedPersona != nil {
                    TextField(
                        "Persona Name",
                        text: Binding(
                            get: { viewModel.selectedPersonaName },
                            set: { viewModel.selectedPersonaName = $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    TextEditor(
                        text: Binding(
                            get: { viewModel.selectedPersonaPrompt },
                            set: { viewModel.selectedPersonaPrompt = $0 }
                        )
                    )
                    .font(.body)
                    .frame(minHeight: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )

                    HStack {
                        Button("Set Active") {
                            viewModel.activateSelectedPersona()
                        }

                        if viewModel.activePersonaID == viewModel.selectedPersona?.id.uuidString {
                            Button("Deactivate") {
                                viewModel.deactivatePersonaRewrite()
                            }
                        }
                    }

                    Text("When enabled, raw transcription can be polished by this persona. If text is selected, spoken instructions remain the primary intent and persona rules act only as output requirements.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Spacer()
                    Text("Select or create a persona to start editing.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(minWidth: 380)
        }
        .padding(.vertical, 6)
    }
}

private struct ErrorLogSettingsTab: View {
    @ObservedObject var errorLogStore: ErrorLogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Error Log")
                    .font(.title2)
                Spacer()
                Button("Clear") {
                    errorLogStore.clear()
                }
                .disabled(errorLogStore.entries.isEmpty)
            }

            if errorLogStore.entries.isEmpty {
                VStack {
                    Spacer()
                    Text("No errors recorded")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(errorLogStore.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.message)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
