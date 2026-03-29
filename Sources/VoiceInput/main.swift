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
    private var languageObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLocalization.shared.setLanguage(SettingsStore().appLanguage)
        AppMenuController.install()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppMenuController.install()
            }
        }
        appCoordinator = AppCoordinator()
        appCoordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appCoordinator?.stop()
    }
}
