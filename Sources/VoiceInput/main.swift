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
        AppMenuController.install()
        appCoordinator = AppCoordinator()
        appCoordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appCoordinator?.stop()
    }
}
