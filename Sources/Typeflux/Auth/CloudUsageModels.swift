import Foundation

struct CloudUsageStats: Decodable, Equatable {
    let asrCount: Int64
    let asrAudioDurationMs: Int64
    let asrOutputChars: Int64
    let chatCount: Int64
    let chatOutputChars: Int64
    let chatInputTokens: Int64
    let chatOutputTokens: Int64
    let chatTotalTokens: Int64

    enum CodingKeys: String, CodingKey {
        case asrCount = "asr_count"
        case asrAudioDurationMs = "asr_audio_duration_ms"
        case asrOutputChars = "asr_output_chars"
        case chatCount = "chat_count"
        case chatOutputChars = "chat_output_chars"
        case chatInputTokens = "chat_input_tokens"
        case chatOutputTokens = "chat_output_tokens"
        case chatTotalTokens = "chat_total_tokens"
    }

    static let empty = CloudUsageStats(
        asrCount: 0,
        asrAudioDurationMs: 0,
        asrOutputChars: 0,
        chatCount: 0,
        chatOutputChars: 0,
        chatInputTokens: 0,
        chatOutputTokens: 0,
        chatTotalTokens: 0,
    )

    var totalRequests: Int64 {
        asrCount + chatCount
    }
}

struct CloudUsageCurrentPeriodStats: Decodable, Equatable {
    let periodStart: String
    let periodEnd: String
    let stats: CloudUsageStats

    enum CodingKeys: String, CodingKey {
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case stats
    }
}
