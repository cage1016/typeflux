import Foundation

enum LocalModelDownloadCatalog {
    private static let sherpaOnnxRuntimeRootDirectory = "sherpa-onnx-v1.12.35-osx-universal2-shared-no-tts"
    private static let senseVoiceRootDirectory = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"
    private static let qwen3ASRRootDirectory = "sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25"

    static func sherpaOnnxRuntimeArchiveURL(source _: ModelDownloadSource) -> URL {
        URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.12.35/\(sherpaOnnxRuntimeRootDirectory).tar.bz2")!
    }

    static var sherpaOnnxRuntimeDirectoryName: String {
        sherpaOnnxRuntimeRootDirectory
    }

    static func sherpaOnnxModelArchiveURL(for model: LocalSTTModel, source _: ModelDownloadSource) -> URL? {
        switch model {
        case .whisperLocal:
            nil
        case .senseVoiceSmall:
            URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/\(senseVoiceRootDirectory).tar.bz2")!
        case .qwen3ASR:
            URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/\(qwen3ASRRootDirectory).tar.bz2")!
        }
    }

    static func sherpaOnnxModelDirectoryName(for model: LocalSTTModel) -> String? {
        switch model {
        case .whisperLocal:
            nil
        case .senseVoiceSmall:
            senseVoiceRootDirectory
        case .qwen3ASR:
            qwen3ASRRootDirectory
        }
    }
}
