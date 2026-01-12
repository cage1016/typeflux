import Foundation

enum PrivacyGuard {
    static var isRunningInAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
