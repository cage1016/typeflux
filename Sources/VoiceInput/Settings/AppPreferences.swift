import Foundation

enum STTProvider: String, CaseIterable, Codable {
    case whisperAPI
    case appleSpeech
    case localModel

    var displayName: String {
        switch self {
        case .whisperAPI:
            return "Whisper API"
        case .appleSpeech:
            return "Apple Speech"
        case .localModel:
            return "Local Model"
        }
    }
}

enum LocalSTTModel: String, CaseIterable, Codable {
    case whisperLocal
    case senseVoiceSmall
    case qwen3ASR

    var displayName: String {
        switch self {
        case .whisperLocal:
            return "Whisper Local"
        case .senseVoiceSmall:
            return "SenseVoice Small"
        case .qwen3ASR:
            return "Qwen3-ASR"
        }
    }

    var defaultModelIdentifier: String {
        switch self {
        case .whisperLocal:
            return "small"
        case .senseVoiceSmall:
            return "iic/SenseVoiceSmall"
        case .qwen3ASR:
            return "Qwen/Qwen3-ASR-0.6B"
        }
    }

    var recommendedDownloadSource: ModelDownloadSource {
        switch self {
        case .whisperLocal:
            return .huggingFace
        case .senseVoiceSmall, .qwen3ASR:
            return .modelScope
        }
    }
}

enum ModelDownloadSource: String, CaseIterable, Codable {
    case modelScope
    case huggingFace

    var displayName: String {
        switch self {
        case .modelScope:
            return "ModelScope"
        case .huggingFace:
            return "Hugging Face"
        }
    }
}

enum LLMProvider: String, CaseIterable, Codable {
    case openAICompatible
    case ollama

    var displayName: String {
        switch self {
        case .openAICompatible:
            return "OpenAI-Compatible"
        case .ollama:
            return "Local Ollama"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

struct PersonaProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var prompt: String

    init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }
}
