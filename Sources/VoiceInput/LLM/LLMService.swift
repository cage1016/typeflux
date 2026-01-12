import Foundation

protocol LLMService {
    func streamEdit(selectedText: String, instruction: String) -> AsyncThrowingStream<String, Error>
}
