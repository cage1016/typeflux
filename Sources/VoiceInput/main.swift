import AppKit
import ApplicationServices

DevLauncher.relaunchAsAppBundleIfNeeded()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appCoordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--prompt-accessibility") {
            // Trigger the system Accessibility prompt as early as possible.
            // If already granted, this is a no-op.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        appCoordinator = AppCoordinator()
        appCoordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appCoordinator?.stop()
    }
}
