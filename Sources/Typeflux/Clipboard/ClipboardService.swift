import AppKit
import Foundation

protocol ClipboardService {
    func write(text: String)
}

final class SystemClipboardService: ClipboardService {
    func write(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
