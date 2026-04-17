import Foundation

enum LocalModelDownloadCatalog {
    private static let huggingFaceEndpoint = "https://huggingface.co"
    private static let huggingFaceChinaMirrorEndpoint = "https://hf-mirror.com"
    private static let whisperKitRepositoryID = "argmaxinc/whisperkit-coreml"
    private static let whisperKitDefaultModelName = "whisperkit-medium"
    private static let sherpaOnnxRuntimeRootDirectory = "sherpa-onnx-v1.12.35-osx-universal2-shared-no-tts"
    private static let senseVoiceRootDirectory = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"
    private static let qwen3ASRRootDirectory = "sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25"

    static var whisperKitDefaultModelIdentifier: String {
        whisperKitDefaultModelName
    }

    static func whisperKitModelRepository(source _: ModelDownloadSource) -> String {
        whisperKitRepositoryID
    }

    static func whisperKitModelRepositoryURL(source: ModelDownloadSource) -> URL {
        URL(string: "\(whisperKitModelEndpoint(source: source))/\(whisperKitRepositoryID)")!
    }

    static func whisperKitModelEndpoint(source: ModelDownloadSource) -> String {
        switch source {
        case .huggingFace:
            huggingFaceEndpoint
        case .modelScope:
            huggingFaceChinaMirrorEndpoint
        }
    }

    static func sherpaOnnxRuntimeArchiveURL(source: ModelDownloadSource) -> URL {
        let archiveName = "\(sherpaOnnxRuntimeRootDirectory).tar.bz2"
        switch source {
        case .huggingFace:
            return URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.12.35/\(archiveName)")!
        case .modelScope:
            return URL(string: "https://sourceforge.net/projects/sherpa-onnx.mirror/files/v1.12.35/\(archiveName)/download")!
        }
    }

    static var sherpaOnnxRuntimeDirectoryName: String {
        sherpaOnnxRuntimeRootDirectory
    }

    static func sherpaOnnxModelArchiveURL(for model: LocalSTTModel, source: ModelDownloadSource) -> URL? {
        switch model {
        case .whisperLocal, .whisperLocalLarge:
            nil
        case .senseVoiceSmall:
            sherpaOnnxASRModelArchiveURL(archiveName: "\(senseVoiceRootDirectory).tar.bz2", source: source)
        case .qwen3ASR:
            sherpaOnnxASRModelArchiveURL(archiveName: "\(qwen3ASRRootDirectory).tar.bz2", source: source)
        }
    }

    static func sherpaOnnxModelDirectoryName(for model: LocalSTTModel) -> String? {
        switch model {
        case .whisperLocal, .whisperLocalLarge:
            nil
        case .senseVoiceSmall:
            senseVoiceRootDirectory
        case .qwen3ASR:
            qwen3ASRRootDirectory
        }
    }

    private static func sherpaOnnxASRModelArchiveURL(archiveName: String, source: ModelDownloadSource) -> URL {
        switch source {
        case .huggingFace:
            URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/\(archiveName)")!
        case .modelScope:
            URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/\(archiveName)")!
        }
    }
}
