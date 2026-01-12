import Foundation

protocol TextInjector {
    func getSelectedText() -> String?
    func insert(text: String) throws
    func replaceSelection(text: String) throws
}
