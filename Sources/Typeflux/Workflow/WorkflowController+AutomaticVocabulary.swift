import Foundation

extension WorkflowController {
    struct AutomaticVocabularyExpectedApp: Equatable {
        let bundleIdentifier: String?
        let processID: pid_t?
        let processName: String?
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func scheduleAutomaticVocabularyObservation(for insertedText: String) {
        automaticVocabularyObservationTask?.cancel()
        automaticVocabularyObservationTask = nil

        guard settingsStore.automaticVocabularyCollectionEnabled else {
            logAutomaticVocabulary("skip scheduling: feature disabled")
            return
        }

        let normalizedInsertedText = insertedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedInsertedText.isEmpty else {
            logAutomaticVocabulary("skip scheduling: inserted text empty after normalization")
            return
        }

        logAutomaticVocabulary(
            "session scheduled | insertedText=\(automaticVocabularyPreview(normalizedInsertedText)) "
                + "| observationWindow=\(Int(Self.automaticVocabularyObservationWindow))s "
                + "| idleSettleDelay=\(Self.automaticVocabularyIdleSettleDelay)s",
        )

        automaticVocabularyObservationTask = Task { [weak self] in
            guard let self else { return }

            guard let initialSnapshot = await readInitialEditableSnapshot() else {
                return
            }
            let expectedApp = automaticVocabularyExpectedApp(from: initialSnapshot)

            do {
                try await Task.sleep(for: Self.automaticVocabularyStartupDelay)
            } catch {
                logAutomaticVocabulary("session cancelled before startup delay finished")
                return
            }

            guard !Task.isCancelled else { return }
            let baselineSnapshot = await readAutomaticVocabularyBaselineWithRetry(
                expectedSubstring: normalizedInsertedText,
            )
            guard let baselineText = baselineSnapshot.text else {
                logAutomaticVocabulary(
                    "session aborted: failed to read baseline input text | "
                        + describeCurrentInputTextSnapshot(baselineSnapshot),
                )
                return
            }
            guard automaticVocabularyMatchesExpectedApp(baselineSnapshot, expectedApp: expectedApp) else {
                logAutomaticVocabulary(
                    "session aborted: focused app changed before baseline was captured | expected="
                        + describeAutomaticVocabularyExpectedApp(expectedApp)
                        + " | actual="
                        + describeCurrentInputTextSnapshot(baselineSnapshot),
                )
                return
            }

            var observationState = AutomaticVocabularyMonitor.makeObservationState(
                baselineText: baselineText,
                startedAt: Date(),
            )
            logAutomaticVocabulary(
                "session started | baselineText=\(automaticVocabularyPreview(baselineText))",
            )
            let deadline = Date().addingTimeInterval(Self.automaticVocabularyObservationWindow)
            var exitReason: AutomaticVocabularySessionExit = .deadlineReached

            pollingLoop: while true {
                let now = Date()
                if now >= deadline {
                    exitReason = .deadlineReached
                    break pollingLoop
                }

                do {
                    try await Task.sleep(for: Self.automaticVocabularyPollInterval)
                } catch {
                    logAutomaticVocabulary("session cancelled during polling")
                    return
                }

                guard !Task.isCancelled else { return }
                let currentSnapshot = await textInjector.currentInputTextSnapshot()
                guard let currentText = currentSnapshot.text else {
                    logAutomaticVocabulary(
                        "poll skipped: failed to read current input text | "
                            + describeCurrentInputTextSnapshot(currentSnapshot),
                    )
                    continue pollingLoop
                }
                guard automaticVocabularyMatchesExpectedApp(currentSnapshot, expectedApp: expectedApp) else {
                    logAutomaticVocabulary(
                        "session aborted: focused app changed during observation | expected="
                            + describeAutomaticVocabularyExpectedApp(expectedApp)
                            + " | actual="
                            + describeCurrentInputTextSnapshot(currentSnapshot),
                    )
                    return
                }

                let pollAt = Date()
                let didChange = AutomaticVocabularyMonitor.observe(
                    text: currentText,
                    at: pollAt,
                    state: &observationState,
                )
                if didChange {
                    logAutomaticVocabulary(
                        "change observed | latestText=\(automaticVocabularyPreview(currentText))",
                    )
                }

                if AutomaticVocabularyMonitor.shouldTriggerAnalysis(
                    state: observationState,
                    now: pollAt,
                    idleSettleDelay: Self.automaticVocabularyIdleSettleDelay,
                ) {
                    exitReason = .settled
                    break pollingLoop
                }
            }

            logAutomaticVocabulary(
                "observation finished | reason=\(exitReason) "
                    + "| finalText=\(automaticVocabularyPreview(observationState.latestObservedText))",
            )

            await runAutomaticVocabularyAnalysis(
                insertedText: normalizedInsertedText,
                baselineText: observationState.baselineText,
                finalText: observationState.latestObservedText,
            )
        }
    }

    func runAutomaticVocabularyAnalysis(
        insertedText: String,
        baselineText: String,
        finalText: String,
    ) async {
        guard finalText != baselineText else {
            logAutomaticVocabulary("analysis skipped: final text unchanged from baseline")
            return
        }

        guard let change = AutomaticVocabularyMonitor.detectChange(
            from: baselineText,
            to: finalText,
        ) else {
            logAutomaticVocabulary("analysis skipped: no candidate terms found after diff")
            return
        }

        if AutomaticVocabularyMonitor.changeIsJustInitialInsertion(
            change: change,
            insertedText: insertedText,
        ) {
            logAutomaticVocabulary("analysis skipped: change resembles initial text insertion")
            return
        }

        if AutomaticVocabularyMonitor.isEditTooLarge(
            inserted: insertedText,
            baseline: baselineText,
            final: finalText,
            ratioLimit: Self.automaticVocabularyEditRatioLimit,
        ) {
            let ratio = AutomaticVocabularyMonitor.editRatio(
                inserted: insertedText,
                baseline: baselineText,
                final: finalText,
            )
            logAutomaticVocabulary(
                "analysis skipped: edit too large | editRatio=\(String(format: "%.2f", ratio)) "
                    + "| insertedLen=\(insertedText.count) "
                    + "| baselineLen=\(baselineText.count) | finalLen=\(finalText.count)",
            )
            return
        }

        let candidateSummary = change.candidateTerms.joined(separator: ", ")
        logAutomaticVocabulary(
            "diff detected | oldFragment=\(automaticVocabularyPreview(change.oldFragment)) "
                + "| newFragment=\(automaticVocabularyPreview(change.newFragment)) "
                + "| candidates=\(candidateSummary)",
        )

        do {
            let acceptedTerms = try await evaluateAutomaticVocabularyCandidates(
                transcript: insertedText,
                change: change,
            )
            let approvedSummary = acceptedTerms.joined(separator: ", ")
            logAutomaticVocabulary("llm decision received | approvedTerms=\(approvedSummary)")
            let addedTerms = addAutomaticVocabularyTerms(acceptedTerms)
            guard !addedTerms.isEmpty else {
                logAutomaticVocabulary("analysis completed: no new terms added")
                return
            }

            let addedSummary = addedTerms.joined(separator: ", ")
            logAutomaticVocabulary("terms added | addedTerms=\(addedSummary)")

            await MainActor.run {
                self.overlayController.showNotice(
                    message: self.automaticVocabularyNotice(for: addedTerms),
                )
            }
        } catch {
            logAutomaticVocabulary("analysis failed: \(error.localizedDescription)")
            ErrorLogStore.shared.log(
                "Automatic vocabulary evaluation failed: \(error.localizedDescription)",
            )
        }
    }

    private func readInitialEditableSnapshot() async -> CurrentInputTextSnapshot? {
        let firstSnapshot = await textInjector.currentInputTextSnapshot()
        if firstSnapshot.isEditable {
            return firstSnapshot
        }

        logAutomaticVocabulary(
            "initial snapshot not editable, retrying | "
                + describeCurrentInputTextSnapshot(firstSnapshot),
        )

        do {
            try await Task.sleep(for: .milliseconds(400))
        } catch {
            return nil
        }

        let retrySnapshot = await textInjector.currentInputTextSnapshot()
        if retrySnapshot.isEditable {
            return retrySnapshot
        }

        logAutomaticVocabulary(
            "session aborted: context is not editable after retry | "
                + describeCurrentInputTextSnapshot(retrySnapshot),
        )
        return nil
    }

    func evaluateAutomaticVocabularyCandidates(
        transcript: String,
        change: AutomaticVocabularyChange,
    ) async throws -> [String] {
        let prompts = PromptCatalog.automaticVocabularyDecisionPrompts(
            transcript: transcript,
            oldFragment: change.oldFragment,
            newFragment: change.newFragment,
            candidateTerms: change.candidateTerms,
            existingTerms: VocabularyStore.activeTerms(),
        )
        let response = try await llmService.completeJSON(
            systemPrompt: prompts.system,
            userPrompt: prompts.user,
            schema: AutomaticVocabularyMonitor.decisionSchema,
        )
        logAutomaticVocabulary("llm raw response | response=\(automaticVocabularyPreview(response))")
        return AutomaticVocabularyMonitor.parseAcceptedTerms(from: response)
    }

    func addAutomaticVocabularyTerms(_ terms: [String]) -> [String] {
        let existingTerms = Set(
            VocabularyStore.activeTerms().map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            },
        )
        var knownTerms = existingTerms
        var addedTerms: [String] = []

        for rawTerm in terms {
            let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = term.lowercased()
            guard !term.isEmpty, !knownTerms.contains(normalized) else { continue }
            _ = VocabularyStore.add(term: term, source: .automatic)
            knownTerms.insert(normalized)
            addedTerms.append(term)
        }

        return addedTerms
    }

    func automaticVocabularyNotice(for terms: [String]) -> String {
        if terms.count == 1, let term = terms.first {
            return L("workflow.vocabulary.autoAdded.single", term)
        }

        return L("workflow.vocabulary.autoAdded.multiple", terms.count)
    }

    func readAutomaticVocabularyBaselineWithRetry(
        expectedSubstring: String? = nil,
    ) async -> CurrentInputTextSnapshot {
        var latestSnapshot = await textInjector.currentInputTextSnapshot()
        if latestSnapshot.text != nil,
           automaticVocabularyBaselineContainsExpected(latestSnapshot.text, expected: expectedSubstring)
        {
            return latestSnapshot
        }

        for attempt in 1 ... Self.automaticVocabularyBaselineRetryCount {
            logAutomaticVocabulary(
                "baseline read retry \(attempt)/\(Self.automaticVocabularyBaselineRetryCount) | "
                    + describeCurrentInputTextSnapshot(latestSnapshot),
            )

            do {
                try await Task.sleep(for: Self.automaticVocabularyBaselineRetryDelay)
            } catch {
                return latestSnapshot
            }

            latestSnapshot = await textInjector.currentInputTextSnapshot()
            if latestSnapshot.text != nil,
               automaticVocabularyBaselineContainsExpected(latestSnapshot.text, expected: expectedSubstring)
            {
                logAutomaticVocabulary(
                    "baseline read recovered on retry \(attempt) | "
                        + describeCurrentInputTextSnapshot(latestSnapshot),
                )
                return latestSnapshot
            }
        }

        if latestSnapshot.text != nil {
            logAutomaticVocabulary(
                "baseline may be stale (expected substring missing) | "
                    + describeCurrentInputTextSnapshot(latestSnapshot),
            )
        }
        return latestSnapshot
    }

    private func automaticVocabularyBaselineContainsExpected(
        _ text: String?,
        expected: String?,
    ) -> Bool {
        guard let expected, !expected.isEmpty else { return true }
        guard let text else { return false }
        let normalizedText = text.lowercased()
        let normalizedExpected = expected.lowercased()
        return normalizedText.contains(normalizedExpected)
    }

    func logAutomaticVocabulary(_ message: String) {
        NetworkDebugLogger.logMessage("[Auto Vocabulary] \(message)")
    }

    func automaticVocabularyPreview(_ text: String, limit: Int = 80) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: "\\n")
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit)) + "..."
    }

    func describeCurrentInputTextSnapshot(_ snapshot: CurrentInputTextSnapshot) -> String {
        let bundleIdentifier = snapshot.bundleIdentifier ?? "<unknown>"
        let processName = snapshot.processName ?? "<unknown>"
        let processID = snapshot.processID.map(String.init) ?? "<unknown>"
        let role = snapshot.role ?? "<unknown>"
        let textPreview = snapshot.text.map { automaticVocabularyPreview($0) } ?? "<nil>"
        let failureReason = snapshot.failureReason ?? "<none>"

        return "bundle=\(bundleIdentifier) | process=\(processName)(pid: \(processID)) | role=\(role) | "
            + "editable=\(snapshot.isEditable) | failureReason=\(failureReason) | text=\(textPreview)"
    }

    func automaticVocabularyExpectedApp(from snapshot: CurrentInputTextSnapshot) -> AutomaticVocabularyExpectedApp {
        AutomaticVocabularyExpectedApp(
            bundleIdentifier: normalizedAutomaticVocabularyAppField(snapshot.bundleIdentifier),
            processID: snapshot.processID,
            processName: normalizedAutomaticVocabularyAppField(snapshot.processName),
        )
    }

    func automaticVocabularyMatchesExpectedApp(
        _ snapshot: CurrentInputTextSnapshot,
        expectedApp: AutomaticVocabularyExpectedApp,
    ) -> Bool {
        if let expectedBundleIdentifier = expectedApp.bundleIdentifier,
           let actualBundleIdentifier = normalizedAutomaticVocabularyAppField(snapshot.bundleIdentifier)
        {
            return expectedBundleIdentifier == actualBundleIdentifier
        }

        if let expectedProcessID = expectedApp.processID,
           let actualProcessID = snapshot.processID
        {
            return expectedProcessID == actualProcessID
        }

        if let expectedProcessName = expectedApp.processName,
           let actualProcessName = normalizedAutomaticVocabularyAppField(snapshot.processName)
        {
            return expectedProcessName == actualProcessName
        }

        return true
    }

    func describeAutomaticVocabularyExpectedApp(_ expectedApp: AutomaticVocabularyExpectedApp) -> String {
        let bundleIdentifier = expectedApp.bundleIdentifier ?? "<unknown>"
        let processName = expectedApp.processName ?? "<unknown>"
        let processID = expectedApp.processID.map(String.init) ?? "<unknown>"
        return "bundle=\(bundleIdentifier) | process=\(processName)(pid: \(processID))"
    }

    func normalizedAutomaticVocabularyAppField(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else { return nil }
        return normalized
    }
}
