import Foundation
import AppKit

/// A mock implementation of an auto-updater.
/// To be replaced with a real API later.
enum AutoUpdater {
    static func checkForUpdates(manual: Bool = true) {
        // Simulating a network request
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let hasUpdate = true // Mock data: always has update for now
            let mockVersion = "2.0.0"
            let mockReleaseNotes = """
- Added new awesome feature
- Fixed several bugs
"""
            
            DispatchQueue.main.async {
                if hasUpdate {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = """
A new version (\(mockVersion)) of VoiceInput is available.

Release Notes:
\(mockReleaseNotes)
"""
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Remind Me Later")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        // Open mock download URL
                        if let url = URL(string: "https://example.com/update") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else if manual {
                    let alert = NSAlert()
                    alert.messageText = "Up to Date"
                    alert.informativeText = "You are running the latest version of VoiceInput."
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
