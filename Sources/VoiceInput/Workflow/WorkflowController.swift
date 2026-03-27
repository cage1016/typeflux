import Foundation

final class WorkflowController {
    private static let recordingTimeoutNanoseconds: UInt64 = 600_000_000_000 // 10 minutes

    private enum ApplyOutcome {
        case inserted
        case copiedToClipboard

        var message: String {
            switch self {
            case .inserted:
                return "Applied to the active app."
            case .copiedToClipboard:
                return "Copied to the clipboard because direct insertion was unavailable."
            }
        }
    }

    private let appState: AppStateStore
    private let settingsStore: SettingsStore
    private let hotkeyService: HotkeyService
    private let audioRecorder: AudioRecorder
    private let sttRouter: STTRouter
    private let llmService: LLMService
    private let textInjector: TextInjector
    private let clipboard: ClipboardService
    private let historyStore: HistoryStore
    private let overlayController: OverlayController

    private var currentSelectedText: String?
    private var isRecording = false
    private var recordingTimeoutTask: Task<Void, Never>?
    private var selectionTask: Task<String?, Never>?

    init(
        appState: AppStateStore,
        settingsStore: SettingsStore,
        hotkeyService: HotkeyService,
        audioRecorder: AudioRecorder,
        sttRouter: STTRouter,
        llmService: LLMService,
        textInjector: TextInjector,
        clipboard: ClipboardService,
        historyStore: HistoryStore,
        overlayController: OverlayController
    ) {
        self.appState = appState
        self.settingsStore = settingsStore
        self.hotkeyService = hotkeyService
        self.audioRecorder = audioRecorder
        self.sttRouter = sttRouter
        self.llmService = llmService
        self.textInjector = textInjector
        self.clipboard = clipboard
        self.historyStore = historyStore
        self.overlayController = overlayController
    }

    func start() {
        hotkeyService.onPressBegan = { [weak self] in
            self?.handlePressBegan()
        }
        hotkeyService.onPressEnded = { [weak self] in
            self?.handlePressEnded()
        }
        hotkeyService.onError = { [weak self] message in
            guard let self else { return }
            ErrorLogStore.shared.log(message)
            Task { @MainActor in
                self.appState.setStatus(.failed(message: message))
                self.overlayController.showFailure(message: message)
                self.overlayController.dismiss(after: 3.0)
            }
        }

        hotkeyService.start()
    }

    func stop() {
        hotkeyService.stop()
        cancelRecording()
    }

    func retry(record: HistoryRecord) {
        guard !isRecording else { return }

        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.appState.setStatus(.processing)
                self.overlayController.showProcessing()
            }
            await self.reprocess(record: record)
        }
    }
    
    /// Force cancel any ongoing recording
    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
        _ = try? audioRecorder.stop()
        Task { @MainActor in
            appState.setStatus(.idle)
            overlayController.dismiss(after: 0.3)
        }
        NSLog("[Workflow] Recording cancelled")
    }

    private func handlePressBegan() {
        // Prevent double-start
        guard !isRecording else {
            NSLog("[Workflow] Already recording, ignoring press")
            return
        }
        
        if !PrivacyGuard.isRunningInAppBundle {
            Task { @MainActor in
                let msg = "Please run via scripts/run_dev_app.sh (app bundle required for privacy permissions)"
                appState.setStatus(.failed(message: "Run as .app"))
                overlayController.showFailure(message: msg)
                overlayController.dismiss(after: 3.0)
                ErrorLogStore.shared.log(msg)
            }
            return
        }

        isRecording = true
        NSLog("[Workflow] Recording started")
        
        Task { @MainActor in
            appState.setStatus(.recording)
            overlayController.show()
        }

        selectionTask = Task { [weak self] in
            guard let self else { return nil }
            let text = await self.textInjector.getSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = (text?.isEmpty == true) ? nil : text
            if let result {
                NSLog("[Workflow] Selected text: \(result)")
            } else {
                NSLog("[Workflow] No selected text")
            }
            return result
        }

        do {
            try audioRecorder.start(levelHandler: { [weak self] level in
                self?.overlayController.updateLevel(level)
            })
            
            // Set a timeout to auto-stop recording after 10 minutes
            recordingTimeoutTask?.cancel()
            recordingTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.recordingTimeoutNanoseconds)
                guard !Task.isCancelled else { return }
                NSLog("[Workflow] Recording timeout - auto stopping")
                self?.handlePressEnded()
            }
        } catch {
            isRecording = false
            var record = HistoryRecord(
                date: Date(),
                recordingStatus: .failed,
                transcriptionStatus: .skipped,
                processingStatus: .skipped,
                applyStatus: .skipped
            )
            record.errorMessage = "Audio start failed: \(error.localizedDescription)"
            historyStore.save(record: record)
            Task { @MainActor in
                let msg = "Audio start failed: \(error.localizedDescription)"
                appState.setStatus(.failed(message: "Audio start failed"))
                overlayController.showFailure(message: msg)
                overlayController.dismiss(after: 3.0)
                ErrorLogStore.shared.log(msg)
            }
        }
    }

    private func handlePressEnded() {
        // Prevent double-end or end without start
        guard isRecording else {
            NSLog("[Workflow] Not recording, ignoring release")
            return
        }
        
        isRecording = false
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
        NSLog("[Workflow] Recording stopped")
        
        Task { @MainActor in
            appState.setStatus(.processing)
            overlayController.showProcessing()
        }

        Task.detached { [weak self] in
            guard let self else { return }
            await self.finishRecordingAndProcess()
        }
    }

    private func generateRewrite(request: LLMRewriteRequest) async throws -> String {
        var buffer = ""
        var lastChunkAt = Date()

        let stream = llmService.streamRewrite(request: request)
        for try await chunk in stream {
            buffer += chunk
            let now = Date()
            if now.timeIntervalSince(lastChunkAt) > 0.15 {
                lastChunkAt = now
                let snapshot = buffer
                await MainActor.run {
                    overlayController.updateStreamingText(snapshot)
                }
            }
        }

        return buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyText(_ text: String, replace: Bool) -> ApplyOutcome {
        clipboard.write(text: text)

        do {
            if replace {
                try textInjector.replaceSelection(text: text)
            } else {
                try textInjector.insert(text: text)
            }
            return .inserted
        } catch {
            // Text is already in clipboard, just show a brief info (not an error)
            Task { @MainActor in
                overlayController.showNotice(message: "已复制到剪贴板 (⌘V 粘贴)")
            }
            return .copiedToClipboard
        }
    }

    private func finishRecordingAndProcess() async {
        do {
            let audioFile = try audioRecorder.stop()
            let selectedText = await selectionTask?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            currentSelectedText = selectedText
            let personaPrompt = settingsStore.activePersona?.prompt

            let record = HistoryRecord(
                date: Date(),
                mode: inferredMode(selectedText: selectedText, personaPrompt: personaPrompt),
                audioFilePath: audioFile.fileURL.path,
                personaPrompt: personaPrompt,
                selectionOriginalText: selectedText,
                recordingStatus: .succeeded,
                transcriptionStatus: .running,
                processingStatus: .pending,
                applyStatus: .pending
            )
            historyStore.save(record: record)

            await process(audioFile: audioFile, record: record, selectedText: selectedText, personaPrompt: personaPrompt)
        } catch {
            let msg = "Processing failed: \(error.localizedDescription)"
            ErrorLogStore.shared.log(msg)

            var record = HistoryRecord(
                date: Date(),
                recordingStatus: .failed,
                transcriptionStatus: .skipped,
                processingStatus: .skipped,
                applyStatus: .skipped
            )
            record.errorMessage = msg
            historyStore.save(record: record)

            await MainActor.run {
                self.appState.setStatus(.failed(message: "Processing failed"))
                self.overlayController.showFailure(message: msg)
                self.overlayController.dismiss(after: 3.0)
            }
        }
    }

    private func reprocess(record: HistoryRecord) async {
        guard let audioFilePath = record.audioFilePath, !audioFilePath.isEmpty else {
            await failRetry(record: record, message: "Retry failed: audio file is missing.")
            return
        }

        let audioURL = URL(fileURLWithPath: audioFilePath)
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            await failRetry(record: record, message: "Retry failed: audio file no longer exists.")
            return
        }

        var mutableRecord = record
        mutableRecord.date = Date()
        mutableRecord.errorMessage = nil
        mutableRecord.applyMessage = nil
        mutableRecord.transcriptText = nil
        mutableRecord.personaResultText = nil
        mutableRecord.selectionEditedText = nil
        mutableRecord.recordingStatus = .succeeded
        mutableRecord.transcriptionStatus = .running
        mutableRecord.processingStatus = .pending
        mutableRecord.applyStatus = .pending
        historyStore.save(record: mutableRecord)

        let audioFile = AudioFile(fileURL: audioURL, duration: 0)
        let selectedText = mutableRecord.selectionOriginalText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let personaPrompt = personaPrompt(for: mutableRecord)
        await process(audioFile: audioFile, record: mutableRecord, selectedText: selectedText, personaPrompt: personaPrompt)
    }

    private func process(
        audioFile: AudioFile,
        record: HistoryRecord,
        selectedText: String?,
        personaPrompt: String?
    ) async {
        var record = record
        do {
            let transcribedText = try await sttRouter.transcribe(audioFile: audioFile)
            record.transcriptText = transcribedText
            record.transcriptionStatus = .succeeded
            historyStore.save(record: record)

            if let selectedText, !selectedText.isEmpty {
                record.mode = .editSelection
                record.processingStatus = .running
                historyStore.save(record: record)

                let finalText = try await generateRewrite(
                    request: LLMRewriteRequest(
                        mode: .editSelection,
                        sourceText: selectedText,
                        spokenInstruction: transcribedText,
                        personaPrompt: personaPrompt
                    )
                )

                record.selectionEditedText = finalText
                record.processingStatus = .succeeded
                record.applyStatus = .running
                historyStore.save(record: record)

                let outcome = applyText(finalText, replace: true)
                record.applyStatus = .succeeded
                record.applyMessage = outcome.message
            } else if let personaPrompt, !personaPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                record.mode = .personaRewrite
                record.processingStatus = .running
                historyStore.save(record: record)

                let finalText = try await generateRewrite(
                    request: LLMRewriteRequest(
                        mode: .rewriteTranscript,
                        sourceText: transcribedText,
                        spokenInstruction: nil,
                        personaPrompt: personaPrompt
                    )
                )

                record.personaResultText = finalText
                record.processingStatus = .succeeded
                record.applyStatus = .running
                historyStore.save(record: record)

                let outcome = applyText(finalText, replace: false)
                record.applyStatus = .succeeded
                record.applyMessage = outcome.message
            } else {
                record.mode = .dictation
                record.processingStatus = .skipped
                record.applyStatus = .running
                historyStore.save(record: record)

                let outcome = applyText(transcribedText, replace: false)
                record.applyStatus = .succeeded
                record.applyMessage = outcome.message
            }

            historyStore.save(record: record)
            historyStore.purge(olderThanDays: 7)

            await MainActor.run {
                self.appState.setStatus(.idle)
                self.overlayController.dismissSoon()
            }
        } catch {
            let msg = "Processing failed: \(error.localizedDescription)"
            ErrorLogStore.shared.log(msg)
            markFailure(&record, message: msg)
            historyStore.save(record: record)

            await MainActor.run {
                self.appState.setStatus(.failed(message: "Processing failed"))
                self.overlayController.showFailure(message: msg)
                self.overlayController.dismiss(after: 3.0)
            }
        }
    }

    private func failRetry(record: HistoryRecord, message: String) async {
        ErrorLogStore.shared.log(message)
        var mutableRecord = record
        mutableRecord.errorMessage = message
        if mutableRecord.audioFilePath == nil {
            mutableRecord.recordingStatus = .failed
        } else if mutableRecord.transcriptText == nil {
            mutableRecord.transcriptionStatus = .failed
        } else {
            mutableRecord.processingStatus = .failed
        }
        historyStore.save(record: mutableRecord)

        await MainActor.run {
            self.appState.setStatus(.failed(message: "Processing failed"))
            self.overlayController.showFailure(message: message)
            self.overlayController.dismiss(after: 3.0)
        }
    }

    private func markFailure(_ record: inout HistoryRecord, message: String) {
        record.errorMessage = message
        if record.transcriptionStatus == .running {
            record.transcriptionStatus = .failed
            record.processingStatus = .skipped
            record.applyStatus = .skipped
            return
        }

        if record.processingStatus == .running {
            record.processingStatus = .failed
            record.applyStatus = .skipped
            return
        }

        if record.applyStatus == .running {
            record.applyStatus = .failed
            return
        }

        record.processingStatus = .failed
    }

    private func inferredMode(selectedText: String?, personaPrompt: String?) -> HistoryRecord.Mode {
        if let selectedText, !selectedText.isEmpty {
            return .editSelection
        }

        if let personaPrompt, !personaPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .personaRewrite
        }

        return .dictation
    }

    private func personaPrompt(for record: HistoryRecord) -> String? {
        switch record.mode {
        case .dictation, .editSelection, .personaRewrite:
            return record.personaPrompt ?? settingsStore.activePersona?.prompt
        }
    }
}
