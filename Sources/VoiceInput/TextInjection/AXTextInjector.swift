import AppKit
import ApplicationServices
import Foundation

final class AXTextInjector: TextInjector {
    private static var didRequestAccessibility = false

    func getSelectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let focused = focusedElement() else { return nil }

        var selected: AnyObject?
        let err = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selected)
        guard err == .success else { return nil }
        return selected as? String
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
