import AVFoundation
import AppKit
import ApplicationServices
import Foundation
import Speech

enum PrivacyGuard {
    static var isRunningInAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    enum PermissionID: String, CaseIterable, Identifiable {
        case microphone
        case speechRecognition
        case accessibility

        var id: String { rawValue }

        var title: String {
            switch self {
            case .microphone:
                return "Microphone"
            case .speechRecognition:
                return "Speech Recognition"
            case .accessibility:
                return "Accessibility"
            }
        }

        var summary: String {
            switch self {
            case .microphone:
                return "Required to capture audio from the system microphone."
            case .speechRecognition:
                return "Required when using Apple Speech for on-device transcription or fallback."
            case .accessibility:
                return "Required to insert or replace text in other apps."
            }
        }
    }

    enum PermissionState: Equatable {
        case granted
        case needsAttention
    }

    struct PermissionSnapshot: Identifiable, Equatable {
        let id: PermissionID
        let state: PermissionState
        let detail: String

        var title: String { id.title }
        var summary: String { id.summary }
        var isGranted: Bool { state == .granted }
        var badgeText: String { isGranted ? "Granted" : "Required" }
        var actionTitle: String { isGranted ? "Open Settings" : "Grant Access" }
    }

    @MainActor
    static func snapshot(for id: PermissionID) -> PermissionSnapshot {
        switch id {
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return PermissionSnapshot(
                id: id,
                state: status == .authorized ? .granted : .needsAttention,
                detail: microphoneDetail(for: status)
            )

        case .speechRecognition:
            let status = SFSpeechRecognizer.authorizationStatus()
            return PermissionSnapshot(
                id: id,
                state: status == .authorized ? .granted : .needsAttention,
                detail: speechRecognitionDetail(for: status)
            )

        case .accessibility:
            let trusted = isAccessibilityGranted()
            return PermissionSnapshot(
                id: id,
                state: trusted ? .granted : .needsAttention,
                detail: trusted
                    ? "VoiceInput can control text fields in other apps."
                    : "Enable Accessibility so VoiceInput can type into the focused app."
            )
        }
    }

    @MainActor
    static func snapshots() -> [PermissionSnapshot] {
        PermissionID.allCases.map(snapshot(for:))
    }

    @MainActor
    static func requestPermission(_ id: PermissionID) async {
        switch id {
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                await openPermissionSettings(for: id)
            case .notDetermined:
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            case .denied, .restricted:
                await openPermissionSettings(for: id)
            @unknown default:
                await openPermissionSettings(for: id)
            }

        case .speechRecognition:
            let status = SFSpeechRecognizer.authorizationStatus()
            switch status {
            case .authorized:
                await openPermissionSettings(for: id)
            case .notDetermined:
                _ = await requestSpeechAuthorization()
            case .denied, .restricted:
                await openPermissionSettings(for: id)
            @unknown default:
                await openPermissionSettings(for: id)
            }

        case .accessibility:
            if isAccessibilityGranted() {
                await openPermissionSettings(for: id)
            } else {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
                await openPermissionSettings(for: id)
            }
        }
    }

    @MainActor
    static func openPermissionSettings(for id: PermissionID) async {
        guard let url = permissionSettingsURL(for: id) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func permissionSettingsURL(for id: PermissionID) -> URL? {
        switch id {
        case .microphone:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechRecognition:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

    private static func isAccessibilityGranted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func microphoneDetail(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "VoiceInput can access the system microphone."
        case .notDetermined:
            return "Grant microphone access to allow recording from the menu bar."
        case .denied:
            return "Microphone access was denied. Re-enable it in System Settings."
        case .restricted:
            return "Microphone access is restricted by the system."
        @unknown default:
            return "Microphone access needs attention."
        }
    }

    private static func speechRecognitionDetail(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Apple Speech can transcribe recordings on this Mac."
        case .notDetermined:
            return "Grant speech recognition to use Apple Speech transcription."
        case .denied:
            return "Speech recognition was denied. Re-enable it in System Settings."
        case .restricted:
            return "Speech recognition is restricted by the system."
        @unknown default:
            return "Speech recognition needs attention."
        }
    }

    @MainActor
    static func requiredPermissionIDs(settingsStore: SettingsStore) -> [PermissionID] {
        var required: [PermissionID] = [
            .microphone,
            .accessibility
        ]

        if settingsStore.sttProvider == .appleSpeech || settingsStore.useAppleSpeechFallback {
            required.append(.speechRecognition)
        }

        return required
    }

    @MainActor
    static func requiredSnapshots(settingsStore: SettingsStore) -> [PermissionSnapshot] {
        requiredPermissionIDs(settingsStore: settingsStore).map(snapshot(for:))
    }

    @MainActor
    static func missingRequiredSnapshots(settingsStore: SettingsStore) -> [PermissionSnapshot] {
        requiredSnapshots(settingsStore: settingsStore).filter { !$0.isGranted }
    }

    @MainActor
    static func openSettingsForPermissions(_ ids: [PermissionID]) {
        let urls = ids.compactMap(permissionSettingsURL(for:))
        for (index, url) in urls.enumerated() {
            let delay = DispatchTime.now() + .milliseconds(index * 250)
            DispatchQueue.main.asyncAfter(deadline: delay) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
