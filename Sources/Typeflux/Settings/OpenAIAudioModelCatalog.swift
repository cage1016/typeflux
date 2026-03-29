import Foundation

enum OpenAIAudioModelCatalog {
    static let whisperEndpoints = [
        "https://api.openai.com/v1/audio/transcriptions"
    ]

    static let whisperModels = [
        "gpt-4o-mini-transcribe",
        "whisper-1",
        "gpt-4o-transcribe"
    ]

    static let multimodalEndpoints = [
        "https://api.openai.com/v1/chat/completions"
    ]

    static let multimodalModels = [
        "gpt-4o-mini-audio-preview",
        "gpt-4o-audio-preview",
        "gpt-audio-mini"
    ]
}
