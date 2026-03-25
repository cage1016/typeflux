import AppKit
import SwiftUI

final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(settingsStore: SettingsStore) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(settingsStore: settingsStore)
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceInput Settings"
        window.center()
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

private struct SettingsView: View {
    @State private var llmBaseURL: String
    @State private var llmModel: String
    @State private var llmAPIKey: String

    @State private var whisperBaseURL: String
    @State private var whisperModel: String
    @State private var whisperAPIKey: String

    @State private var enableFn: Bool
    @State private var appleSpeechFallback: Bool

    @State private var customHotkeys: [HotkeyBinding]
    @StateObject private var recorder = HotkeyRecorder()

    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        _llmBaseURL = State(initialValue: settingsStore.llmBaseURL)
        _llmModel = State(initialValue: settingsStore.llmModel)
        _llmAPIKey = State(initialValue: settingsStore.llmAPIKey)

        _whisperBaseURL = State(initialValue: settingsStore.whisperBaseURL)
        _whisperModel = State(initialValue: settingsStore.whisperModel)
        _whisperAPIKey = State(initialValue: settingsStore.whisperAPIKey)

        _enableFn = State(initialValue: settingsStore.enableFnHotkey)
        _appleSpeechFallback = State(initialValue: settingsStore.useAppleSpeechFallback)

        _customHotkeys = State(initialValue: settingsStore.customHotkeys)
    }

    @StateObject private var errorLogStore = ErrorLogStore.shared

    var body: some View {
        TabView {
            hotkeyTab
                .tabItem { Text("Hotkey") }
            sttTab
                .tabItem { Text("STT") }
            llmTab
                .tabItem { Text("LLM") }
            errorLogTab
                .tabItem {
                    HStack {
                        Text("Errors")
                        if !errorLogStore.entries.isEmpty {
                            Text("(\(errorLogStore.entries.count))")
                                .foregroundColor(.red)
                        }
                    }
                }
        }
        .padding(14)
        .frame(minWidth: 560, minHeight: 420)
    }

    private var hotkeyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hotkey")
                .font(.title2)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
//                    Toggle("Enable Fn (press-and-hold)", isOn: $enableFn)
//                        .onChange(of: enableFn) { settingsStore.enableFnHotkey = $0 }
                    Toggle("Enable Right Command (press-and-hold, temporary debug override)", isOn: $enableFn)
                        .onChange(of: enableFn) { settingsStore.enableFnHotkey = $0 }

                    HStack {
                        Button(recorder.isRecording ? "Recording…" : "Add Custom Hotkey") {
                            if recorder.isRecording {
                                recorder.stop()
                            } else {
                                recorder.start { binding in
                                    var list = customHotkeys
                                    if !list.contains(where: { $0.keyCode == binding.keyCode && $0.modifierFlags == binding.modifierFlags }) {
                                        list.append(binding)
                                        customHotkeys = list
                                        settingsStore.customHotkeys = list
                                    }
                                }
                            }
                        }
                        .disabled(recorder.isRecording == false ? false : false)

                        Text("Press a key with modifiers (⌘/⌥/⌃/⇧) to record")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if customHotkeys.isEmpty {
                        Text("No custom hotkeys yet")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        List {
                            ForEach(customHotkeys) { binding in
                                HStack {
                                    Text(HotkeyFormat.display(binding))
                                    Spacer()
                                    Button("Remove") {
                                        customHotkeys.removeAll { $0.id == binding.id }
                                        settingsStore.customHotkeys = customHotkeys
                                    }
                                }
                            }
                        }
                        .frame(height: 160)
                    }
                }
                .padding(6)
            } label: {
                Text("Bindings")
            }

            Spacer()
        }
    }

    private var sttTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speech To Text")
                .font(.title2)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Whisper Base URL", text: $whisperBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: whisperBaseURL) { settingsStore.whisperBaseURL = $0 }
                    TextField("Whisper Model", text: $whisperModel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: whisperModel) { settingsStore.whisperModel = $0 }
                    SecureField("Whisper API Key", text: $whisperAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: whisperAPIKey) { settingsStore.whisperAPIKey = $0 }

                    Toggle("Enable Apple Speech fallback", isOn: $appleSpeechFallback)
                        .onChange(of: appleSpeechFallback) { settingsStore.useAppleSpeechFallback = $0 }
                }
                .padding(6)
            } label: {
                Text("Whisper / OpenAI-compatible transcriptions")
            }

            Spacer()
        }
    }

    private var llmTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LLM")
                .font(.title2)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Base URL", text: $llmBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: llmBaseURL) { settingsStore.llmBaseURL = $0 }
                    TextField("Model", text: $llmModel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: llmModel) { settingsStore.llmModel = $0 }
                    SecureField("API Key", text: $llmAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: llmAPIKey) { settingsStore.llmAPIKey = $0 }
                }
                .padding(6)
            } label: {
                Text("OpenAI-compatible Chat")
            }

            Spacer()
        }
    }

    private var errorLogTab: some View {
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
