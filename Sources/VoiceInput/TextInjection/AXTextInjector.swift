import AppKit
import ApplicationServices
import Foundation

final class AXTextInjector: TextInjector {
    private static var didRequestAccessibility = false

    func getSelectedText() async -> String? {
        guard AXIsProcessTrusted() else {
            if !Self.didRequestAccessibility {
                Self.didRequestAccessibility = true
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return nil
        }

        let pboard = NSPasteboard.general
        let oldChangeCount = pboard.changeCount
        let oldString = pboard.string(forType: .string)

        // Send Cmd+C
        let src = CGEventSource(stateID: .combinedSessionState)
        let cDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true) // 0x08 is kVK_ANSI_C
        cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand

        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)

        // Wait for change count to increment (up to 300ms)
        var didChange = false
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            if pboard.changeCount != oldChangeCount {
                didChange = true
                break
            }
        }

        let newString: String?
        if didChange {
            newString = pboard.string(forType: .string)
        } else {
            newString = nil
        }

        // Restore previous pasteboard content
        if let old = oldString {
            pboard.clearContents()
            pboard.setString(old, forType: .string)
        } else {
            pboard.clearContents()
        }

        return newString
    }

    func insert(text: String) throws {
        try setTextViaPaste(text)
    }

    func replaceSelection(text: String) throws {
        try setTextViaPaste(text)
    }

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success else { return nil }
        return (focused as! AXUIElement)
    }

    private func setTextViaPaste(_ text: String) throws {
        if !AXIsProcessTrusted() {
            if !Self.didRequestAccessibility {
                Self.didRequestAccessibility = true
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            throw NSError(
                domain: "AXTextInjector",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Accessibility permission required"]
            )
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let src = CGEventSource(stateID: .combinedSessionState)

        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // kVK_ANSI_V
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
