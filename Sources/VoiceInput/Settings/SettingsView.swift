import SwiftUI

struct StudioView: View {
    @ObservedObject var viewModel: StudioViewModel
    @StateObject private var recorder = HotkeyRecorder()

    var body: some View {
        StudioShell(
            currentSection: viewModel.currentSection,
            onSelect: viewModel.navigate,
            searchText: $viewModel.searchQuery,
            searchPlaceholder: viewModel.currentSection.searchPlaceholder
        ) {
            VStack(alignment: .leading, spacing: 24) {
                StudioHeroHeader(
                    eyebrow: viewModel.currentSection.eyebrow,
                    title: viewModel.currentSection.heading,
                    subtitle: viewModel.currentSection.subheading
                )

                currentPage
            }
        }
        .preferredColorScheme(viewModel.preferredColorScheme)
        .overlay(alignment: .bottomTrailing) {
            if viewModel.currentSection == .home {
                Button(action: { viewModel.navigate(to: .settings) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(StudioTheme.accent))
                }
                .buttonStyle(.plain)
                .shadow(color: StudioTheme.accent.opacity(0.25), radius: 18, x: 0, y: 10)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.studioBody(14, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(StudioTheme.surface)
                    )
                    .overlay(Capsule().stroke(StudioTheme.border, lineWidth: 1))
                    .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch viewModel.currentSection {
        case .home:
            homePage
        case .models:
            modelsPage
        case .personas:
            personasPage
        case .history:
            historyPage
        case .debug:
            debugPage
        case .settings:
            settingsPage
        }
    }

    private var homePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 22) {
                StudioMetricCard(
                    icon: "stopwatch.fill",
                    value: viewModel.transcriptionMinutesText,
                    caption: "Total minutes processed",
                    badge: "+12% from last week"
                )
                StudioMetricCard(
                    icon: "doc.text.fill",
                    value: viewModel.completedTranscriptionsText,
                    caption: "Completed transcriptions",
                    badge: nil
                )
            }

            HStack {
                Text("Recent Transcriptions")
                    .font(.studioDisplay(18, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                StudioButton(title: "Export All", systemImage: nil, variant: .secondary) {
                    viewModel.exportHistory()
                }
                StudioButton(title: "Open Settings", systemImage: nil, variant: .primary) {
                    viewModel.navigate(to: .settings)
                }
            }

            historyTable(records: Array(viewModel.displayedHistory.prefix(4)))
        }
    }

    private var modelsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                ForEach(StudioModelDomain.allCases) { domain in
                    Button {
                        viewModel.setModelDomain(domain)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: domain.iconName)
                            Text("\(domain.title) (\(domain.subtitle))")
                        }
                        .font(.studioBody(14, weight: .semibold))
                        .foregroundStyle(viewModel.modelDomain == domain ? StudioTheme.accent : StudioTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(viewModel.modelDomain == domain ? StudioTheme.surface : StudioTheme.surfaceMuted)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .top, spacing: 22) {
                StudioCard {
                    StudioSectionTitle(title: "Architecture Mode")
                    Text(viewModel.currentArchitectureTitle)
                        .font(.studioDisplay(24, weight: .bold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(viewModel.currentArchitectureDescription)
                        .font(.studioBody(13))
                        .foregroundStyle(StudioTheme.textSecondary)

                    VStack(spacing: 14) {
                        architectureModeButton(title: "Local Processing", subtitle: "On-device privacy", isActive: isLocalArchitecture)
                        architectureModeButton(title: "Remote API", subtitle: "High-performance cloud", isActive: !isLocalArchitecture)
                    }
                }
                .frame(width: 320)

                VStack(spacing: 22) {
                    HStack(spacing: 22) {
                        ForEach(viewModel.architectureCards) { card in
                            modelCard(card)
                        }
                    }

                    HStack(alignment: .top, spacing: 22) {
                        parameterCard
                        actionCard
                    }
                }
            }

            HStack {
                Spacer()
                StudioButton(title: "Reset Changes", systemImage: nil, variant: .secondary) {
                    viewModel.navigate(to: .models)
                }
                StudioButton(title: "Apply Configuration", systemImage: "bolt.fill", variant: .primary) {
                    viewModel.applyModelConfiguration()
                }
            }
        }
    }

    private var personasPage: some View {
        HStack(alignment: .top, spacing: 28) {
            StudioCard {
                HStack {
                        Text("Persona Roster")
                        .font(.studioDisplay(20, weight: .bold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Spacer()
                    Button(action: viewModel.addPersona) {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(StudioTheme.accent))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    ForEach(viewModel.filteredPersonas) { persona in
                        Button {
                            viewModel.selectPersona(persona.id)
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(StudioTheme.accentSoft)
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Text(String(persona.name.prefix(2)).uppercased())
                                            .font(.studioBody(14, weight: .bold))
                                            .foregroundStyle(StudioTheme.accent)
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(persona.name)
                                        .font(.studioBody(15, weight: .semibold))
                                        .foregroundStyle(StudioTheme.textPrimary)
                                    Text(persona.prompt)
                                        .font(.studioBody(12))
                                        .foregroundStyle(StudioTheme.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Circle()
                                    .fill(persona.id.uuidString == viewModel.activePersonaID ? StudioTheme.accent : Color.clear)
                                    .frame(width: 10, height: 10)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(viewModel.selectedPersonaID == persona.id ? StudioTheme.surfaceMuted : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 360)

            StudioCard {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Editing Active Persona".uppercased())
                            .font(.studioBody(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(StudioTheme.textSecondary)
                        Text(viewModel.selectedPersona?.name ?? "No Persona Selected")
                            .font(.studioDisplay(28, weight: .bold))
                            .foregroundStyle(StudioTheme.textPrimary)
                    }
                    Spacer()
                    StudioButton(title: "Discard", systemImage: nil, variant: .secondary) {
                        viewModel.refreshHistory()
                    }
                    StudioButton(title: "Save Changes", systemImage: nil, variant: .primary) {
                        viewModel.applyModelConfiguration()
                    }
                }

                Divider().overlay(StudioTheme.border)

                VStack(alignment: .leading, spacing: 18) {
                    StudioSectionTitle(title: "Core Identity")
                    StudioTextInputCard(
                        label: "Persona Name",
                        placeholder: "Enter persona name",
                        text: Binding(
                            get: { viewModel.selectedPersonaName },
                            set: { viewModel.selectedPersonaName = $0 }
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        StudioSectionTitle(title: "System Prompt")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.personaRewriteEnabled },
                            set: viewModel.setPersonaRewriteEnabled
                        ))
                        .toggleStyle(.switch)
                    }

                    TextEditor(
                        text: Binding(
                            get: { viewModel.selectedPersonaPrompt },
                            set: { viewModel.selectedPersonaPrompt = $0 }
                        )
                    )
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 360)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(StudioTheme.surfaceMuted)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(StudioTheme.border, lineWidth: 1)
                    )

                    HStack {
                        Text("Persona rewrite is \(viewModel.personaRewriteEnabled ? "enabled" : "disabled").")
                            .font(.studioBody(12))
                            .foregroundStyle(StudioTheme.textSecondary)
                        Spacer()
                        StudioButton(title: "Delete", systemImage: nil, variant: .ghost) {
                            viewModel.deleteSelectedPersona()
                        }
                        StudioButton(title: "Set Active", systemImage: nil, variant: .primary) {
                            viewModel.activateSelectedPersona()
                        }
                    }
                }
            }
        }
    }

    private var historyPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                StudioButton(title: "Refresh", systemImage: "arrow.clockwise", variant: .secondary) {
                    viewModel.refreshHistory()
                }
                StudioButton(title: "Export Markdown", systemImage: "square.and.arrow.up", variant: .primary) {
                    viewModel.exportHistory()
                }
                Spacer()
                StudioButton(title: "Clear", systemImage: "trash", variant: .ghost) {
                    viewModel.clearHistory()
                }
            }

            historyTable(records: viewModel.displayedHistory)
        }
    }

    private var debugPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 22) {
                StudioCard {
                    StudioSectionTitle(title: "Runtime Status")
                    debugLine(title: "STT Provider", value: viewModel.sttProvider.displayName)
                    debugLine(title: "LLM Provider", value: viewModel.llmProvider.displayName)
                    debugLine(title: "Ollama", value: viewModel.ollamaStatus)
                }

                StudioCard {
                    StudioSectionTitle(title: "Quick Actions")
                    StudioButton(title: "Prepare Local Model", systemImage: "arrow.down.circle", variant: .primary) {
                        viewModel.prepareOllamaModel()
                    }
                    StudioButton(title: "Open Models", systemImage: "cpu", variant: .secondary) {
                        viewModel.navigate(to: .models)
                    }
                }
                .frame(width: 320)
            }

            StudioCard {
                HStack {
                    Text("Recent Errors")
                        .font(.studioDisplay(18, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Spacer()
                    StudioButton(title: "Clear", systemImage: nil, variant: .ghost) {
                        viewModel.errorLogStore.clear()
                    }
                }

                if viewModel.errorLogStore.entries.isEmpty {
                    Text("No errors recorded.")
                        .font(.studioBody(13))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .padding(.vertical, 18)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.errorLogStore.entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.date, style: .time)
                                    .font(.studioBody(10, weight: .semibold))
                                    .foregroundStyle(StudioTheme.textSecondary)
                                Text(entry.message)
                                    .font(.studioBody(13))
                                    .foregroundStyle(StudioTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)

                            if entry.id != viewModel.errorLogStore.entries.last?.id {
                                Divider().overlay(StudioTheme.border)
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioSectionTitle(title: "General Behaviour")

            StudioCard {
                StudioSettingRow(
                    title: "Enable Press-and-Hold Hotkey",
                    subtitle: "Keep the recorder ready from the menu bar with your debug override hotkey."
                ) {
                    Toggle("", isOn: Binding(get: { viewModel.enableFn }, set: viewModel.setEnableFn))
                        .toggleStyle(.switch)
                }

                Divider().overlay(StudioTheme.border)

                StudioSettingRow(
                    title: "Use Apple Speech as Fallback",
                    subtitle: "Drop back to the local system recognizer when Whisper is unavailable."
                ) {
                    Toggle("", isOn: Binding(get: { viewModel.appleSpeechFallback }, set: viewModel.setAppleSpeechFallback))
                        .toggleStyle(.switch)
                }
            }

            StudioSectionTitle(title: "Identity & Interaction")

            HStack(alignment: .top, spacing: 22) {
                StudioCard {
                    Text("Default Persona")
                        .font(.studioDisplay(16, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("Select the voice identity used for new dictation sessions.")
                        .font(.studioBody(13))
                        .foregroundStyle(StudioTheme.textSecondary)

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.selectedPersonaID },
                            set: viewModel.selectPersona
                        )
                    ) {
                        ForEach(viewModel.personas) { persona in
                            Text(persona.name).tag(Optional(persona.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    StudioButton(title: "Open Personas", systemImage: nil, variant: .ghost) {
                        viewModel.navigate(to: .personas)
                    }
                }
                .frame(maxWidth: .infinity)

                StudioCard {
                    Text("Activation Hotkey")
                        .font(.studioDisplay(16, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("The keyboard shortcut used to trigger voice recording.")
                        .font(.studioBody(13))
                        .foregroundStyle(StudioTheme.textSecondary)

                    if let first = viewModel.customHotkeys.first {
                        Text(HotkeyFormat.display(first))
                            .font(.studioBody(14, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(StudioTheme.surfaceMuted)
                            )
                    } else {
                        Text("Option + Space")
                            .font(.studioBody(14, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(StudioTheme.surfaceMuted)
                            )
                    }

                    Button(recorder.isRecording ? "Recording…" : "Record New") {
                        if recorder.isRecording {
                            recorder.stop()
                        } else {
                            recorder.start { binding in
                                viewModel.addHotkey(binding)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(StudioTheme.accent)
                }
                .frame(maxWidth: .infinity)
            }

            StudioCard {
                HStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(StudioTheme.accentSoft)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "paintbrush.pointed.fill")
                                .foregroundStyle(StudioTheme.accent)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Appearance")
                            .font(.studioDisplay(16, weight: .semibold))
                            .foregroundStyle(StudioTheme.textPrimary)
                        Text("Switch the component system between light, dark, or system-following themes.")
                            .font(.studioBody(13))
                            .foregroundStyle(StudioTheme.textSecondary)
                    }

                    Spacer()

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.appearanceMode },
                            set: viewModel.setAppearanceMode
                        )
                    ) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
            }
        }
    }

    private var parameterCard: some View {
        StudioCard {
            StudioSectionTitle(title: "Configuration")
            if viewModel.modelDomain == .stt {
                StudioTextInputCard(label: "Whisper Base URL", placeholder: "https://api.openai.com/v1", text: Binding(get: { viewModel.whisperBaseURL }, set: viewModel.setWhisperBaseURL))
                StudioTextInputCard(label: "Whisper Model", placeholder: "whisper-1", text: Binding(get: { viewModel.whisperModel }, set: viewModel.setWhisperModel))
                Toggle("Enable Apple fallback", isOn: Binding(get: { viewModel.appleSpeechFallback }, set: viewModel.setAppleSpeechFallback))
                    .toggleStyle(.switch)
            } else {
                if viewModel.llmProvider == .ollama {
                    StudioTextInputCard(label: "Ollama Base URL", placeholder: "http://127.0.0.1:11434", text: Binding(get: { viewModel.ollamaBaseURL }, set: viewModel.setOllamaBaseURL))
                    StudioTextInputCard(label: "Local Model", placeholder: "qwen2.5:7b", text: Binding(get: { viewModel.ollamaModel }, set: viewModel.setOllamaModel))
                    Toggle("Automatic local setup", isOn: Binding(get: { viewModel.ollamaAutoSetup }, set: viewModel.setOllamaAutoSetup))
                        .toggleStyle(.switch)
                } else {
                    StudioTextInputCard(label: "Remote Base URL", placeholder: "https://api.openai.com/v1", text: Binding(get: { viewModel.llmBaseURL }, set: viewModel.setLLMBaseURL))
                    StudioTextInputCard(label: "Model", placeholder: "gpt-4o-mini", text: Binding(get: { viewModel.llmModel }, set: viewModel.setLLMModel))
                    StudioTextInputCard(label: "API Key", placeholder: "sk-...", text: Binding(get: { viewModel.llmAPIKey }, set: viewModel.setLLMAPIKey), secure: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var actionCard: some View {
        StudioCard {
            StudioSectionTitle(title: "Activation")
            Text("Custom Architecture?")
                .font(.studioDisplay(17, weight: .bold))
                .foregroundStyle(.white)
            Text("Import your own gateway URL or prepare a local model directly from the component-driven configuration panels.")
                .font(.studioBody(14))
                .foregroundStyle(Color.white.opacity(0.84))

            Spacer(minLength: 12)

            HStack {
                StudioPill(title: "CoreML", tone: .white, fill: Color.white.opacity(0.18))
                StudioPill(title: "ONNX", tone: .white, fill: Color.white.opacity(0.18))
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [StudioTheme.accent, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func historyTable(records: [HistoryPresentationRecord]) -> some View {
        StudioCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Timestamp")
                        .frame(width: 170, alignment: .leading)
                    Text("Source File")
                        .frame(width: 280, alignment: .leading)
                    Text("Recognized Text")
                    Spacer()
                }
                .font(.studioBody(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(StudioTheme.textSecondary)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 10)

                Divider().overlay(StudioTheme.border)

                if records.isEmpty {
                    Text("No history entries yet.")
                        .font(.studioBody(13))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 44)
                } else {
                    ForEach(records) { record in
                        StudioHistoryRow(record: record)
                        if record.id != records.last?.id {
                            Divider().overlay(StudioTheme.border)
                        }
                    }
                }
            }
        }
    }

    private func modelCard(_ card: StudioModelCard) -> some View {
        StudioCard {
            HStack {
                StudioPill(title: card.badge)
                Spacer()
                if card.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }

            Text(card.name)
                .font(.studioDisplay(20, weight: .bold))
                .foregroundStyle(card.isMuted ? StudioTheme.textSecondary : StudioTheme.textPrimary)
            Text(card.summary)
                .font(.studioBody(13))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack {
                Text(card.metadata)
                    .font(.studioBody(14))
                    .foregroundStyle(StudioTheme.textSecondary)
                Spacer()
                StudioButton(title: card.actionTitle, systemImage: nil, variant: card.isSelected ? .secondary : .primary) {
                    handleModelSelection(card)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .opacity(card.isMuted ? 0.56 : 1)
    }

    private var isLocalArchitecture: Bool {
        switch viewModel.modelDomain {
        case .stt:
            return viewModel.sttProvider == .appleSpeech
        case .llm:
            return viewModel.llmProvider == .ollama
        }
    }

    private func architectureModeButton(title: String, subtitle: String, isActive: Bool) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? StudioTheme.accentSoft : StudioTheme.surfaceMuted)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: title.contains("Local") ? "cpu.fill" : "cloud.fill")
                        .foregroundStyle(isActive ? StudioTheme.accent : StudioTheme.textSecondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.studioBody(15, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(subtitle)
                    .font(.studioBody(12))
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer()
            Circle()
                .stroke(isActive ? StudioTheme.accent : StudioTheme.border, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .fill(isActive ? StudioTheme.accent : Color.clear)
                        .frame(width: 10, height: 10)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? StudioTheme.surface : StudioTheme.surfaceMuted)
        )
    }

    private func handleModelSelection(_ card: StudioModelCard) {
        switch card.id {
        case "apple-speech":
            viewModel.setSTTModelSelection(.appleSpeech, suggestedModel: viewModel.whisperModel)
        case "whisper-api":
            viewModel.setSTTModelSelection(.whisperAPI, suggestedModel: viewModel.whisperModel.isEmpty ? "whisper-1" : viewModel.whisperModel)
        case "ollama-local":
            viewModel.setLLMModelSelection(.ollama, suggestedModel: viewModel.ollamaModel.isEmpty ? "qwen2.5:7b" : viewModel.ollamaModel)
        case "openai-compatible":
            viewModel.setLLMModelSelection(.openAICompatible, suggestedModel: viewModel.llmModel.isEmpty ? "gpt-4o-mini" : viewModel.llmModel)
        default:
            break
        }
    }

    private func debugLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.studioBody(13, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.studioBody(13))
                .foregroundStyle(StudioTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
