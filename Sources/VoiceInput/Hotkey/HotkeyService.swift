import Foundation

protocol HotkeyService: AnyObject {
    var onPressBegan: (() -> Void)? { get set }
    var onPressEnded: (() -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }

    func start()
    func stop()
}
