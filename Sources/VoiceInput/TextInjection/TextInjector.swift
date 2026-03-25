import Foundation

protocol TextInjector {
    func getSelectedText() async -> String?
    func insert(text: String) throws
    func replaceSelection(text: String) throws
}
