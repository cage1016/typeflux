import Foundation

enum StudioSection: String, CaseIterable, Identifiable {
    case home
    case models
    case personas
    case history
    case debug
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .models: return "Models"
        case .personas: return "Personas"
        case .history: return "History"
        case .debug: return "Debug"
        case .settings: return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .models: return "cpu"
        case .personas: return "face.smiling"
        case .history: return "clock.arrow.circlepath"
        case .debug: return "terminal"
        case .settings: return "gearshape.fill"
        }
    }

    var eyebrow: String {
        switch self {
        case .home: return "Overview"
        case .models: return "Models Configuration"
        case .personas: return "Personas Management"
        case .history: return "Voice History"
        case .debug: return "Diagnostics"
        case .settings: return "Settings"
        }
    }

    var heading: String {
        switch self {
        case .home: return "Good Morning, Creator"
        case .models: return "Intelligence Engines."
        case .personas: return "Personas"
        case .history: return "Recent Sessions"
        case .debug: return "Debug Console"
        case .settings: return "Preferences"
        }
    }

    var subheading: String {
        switch self {
        case .home:
            return "Here is your voice activity and editing momentum over the last 7 days."
        case .models:
            return "Configure the local and cloud architectures that power transcription and rewriting."
        case .personas:
            return "Curate reusable writing identities and keep their prompts validated."
        case .history:
            return "Browse processed sessions, inspect recognized text, and export your timeline."
        case .debug:
            return "Inspect recent failures, connectivity hints, and model preparation status."
        case .settings:
            return "Configure how Voice Studio behaves on your system and personalize your interaction experience."
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .home: return "Search activity..."
        case .models: return "Search models..."
        case .personas: return "Search personas..."
        case .history: return "Search history..."
        case .debug: return "Search logs..."
        case .settings: return "Search settings..."
        }
    }
}

enum StudioModelDomain: String, CaseIterable, Identifiable {
    case stt
    case llm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stt: return "Voice Transcription"
        case .llm: return "LLM"
        }
    }

    var subtitle: String {
        switch self {
        case .stt: return "语音转写"
        case .llm: return "大语言模型"
        }
    }

    var iconName: String {
        switch self {
        case .stt: return "waveform"
        case .llm: return "ellipsis.message"
        }
    }
}

struct StudioModelCard: Identifiable {
    let id: String
    let name: String
    let summary: String
    let badge: String
    let metadata: String
    let isSelected: Bool
    let isMuted: Bool
    let actionTitle: String
}

struct HistoryPresentationRecord: Identifiable {
    let id: UUID
    let timestampText: String
    let sourceName: String
    let previewText: String
    let accentName: String
    let accentColorName: String
}
