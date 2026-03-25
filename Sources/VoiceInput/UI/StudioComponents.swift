import SwiftUI

struct StudioShell<Content: View>: View {
    let currentSection: StudioSection
    let onSelect: (StudioSection) -> Void
    let searchText: Binding<String>
    let searchPlaceholder: String
    let content: Content

    init(
        currentSection: StudioSection,
        onSelect: @escaping (StudioSection) -> Void,
        searchText: Binding<String>,
        searchPlaceholder: String,
        @ViewBuilder content: () -> Content
    ) {
        self.currentSection = currentSection
        self.onSelect = onSelect
        self.searchText = searchText
        self.searchPlaceholder = searchPlaceholder
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            StudioSidebar(currentSection: currentSection, onSelect: onSelect)
                .frame(width: StudioTheme.sidebarWidth)

            VStack(spacing: 0) {
                ScrollView {
                    content
                        .frame(maxWidth: StudioTheme.contentMaxWidth, alignment: .leading)
                        .padding(.horizontal, StudioTheme.contentInset)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .background(StudioTheme.background)
        }
        .background(StudioTheme.background)
    }
}

struct StudioSidebar: View {
    let currentSection: StudioSection
    let onSelect: (StudioSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Studio")
                    .font(.studioDisplay(16, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("macOS Sequioa Edition".uppercased())
                    .font(.studioBody(9, weight: .semibold))
                    .tracking(2.1)
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 26)

            VStack(spacing: 6) {
                ForEach(StudioSection.allCases) { section in
                    Button(action: { onSelect(section) }) {
                        HStack(spacing: 14) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 18)
                            Text(section.title)
                                .font(.studioBody(14, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(section == currentSection ? StudioTheme.textPrimary : StudioTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(section == currentSection ? StudioTheme.surfaceMuted : Color.clear)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            HStack(spacing: 12) {
                Circle()
                    .fill(StudioTheme.accentSoft)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text("VI")
                            .font(.studioBody(12, weight: .bold))
                            .foregroundStyle(StudioTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("VoiceInput Pro")
                        .font(.studioBody(12, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("Reusable UI System")
                        .font(.studioBody(10))
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(StudioTheme.sidebar)
    }
}

struct StudioHeroHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow.uppercased())
                .font(.studioBody(11, weight: .bold))
                .tracking(2.6)
                .foregroundStyle(StudioTheme.textSecondary)
            Text(title)
                .font(.studioDisplay(36, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)
            Text(subtitle)
                .font(.studioBody(14))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(maxWidth: 620, alignment: .leading)
        }
    }
}

struct StudioSectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.studioBody(10, weight: .bold))
            .tracking(2.3)
            .foregroundStyle(StudioTheme.textSecondary)
    }
}

struct StudioCard<Content: View>: View {
    var padding: CGFloat = 20
    let content: Content

    init(padding: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StudioTheme.surface)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(StudioTheme.border, lineWidth: 1)
        )
    }
}

struct StudioButton: View {
    enum Variant {
        case primary
        case secondary
        case ghost
    }

    let title: String
    let systemImage: String?
    let variant: Variant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.studioBody(14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 88)
        }
        .buttonStyle(.plain)
        .background(background)
        .foregroundStyle(foreground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(variant == .ghost ? Color.clear : StudioTheme.border, lineWidth: variant == .primary ? 0 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var background: some View {
        Group {
            switch variant {
            case .primary:
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudioTheme.accent)
            case .secondary:
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudioTheme.surface)
            case .ghost:
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.clear)
            }
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return StudioTheme.textPrimary
        case .ghost:
            return StudioTheme.accent
        }
    }
}

struct StudioPill: View {
    let title: String
    var tone: Color = StudioTheme.accent
    var fill: Color = StudioTheme.accentSoft

    var body: some View {
        Text(title.uppercased())
            .font(.studioBody(10, weight: .bold))
            .foregroundStyle(tone)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(fill))
    }
}

struct StudioMetricCard: View {
    let icon: String
    let value: String
    let caption: String
    let badge: String?

    var body: some View {
        StudioCard {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(StudioTheme.accentSoft)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(StudioTheme.accent)
                    )
                Spacer()
                if let badge {
                    StudioPill(title: badge)
                }
            }

            Spacer(minLength: 24)

            Text(value)
                .font(.studioDisplay(40, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)
            Text(caption)
                .font(.studioBody(14))
                .foregroundStyle(StudioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .leading)
    }
}

struct StudioSettingRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let accessory: Accessory

    init(title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.studioDisplay(17, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(subtitle)
                    .font(.studioBody(14))
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer()
            accessory
        }
        .padding(.vertical, 8)
    }
}

struct StudioTextInputCard: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label.uppercased())
                .font(.studioBody(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(StudioTheme.textSecondary)

            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.studioBody(15))
            .foregroundStyle(StudioTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(StudioTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(StudioTheme.border, lineWidth: 1)
            )
        }
    }
}

struct StudioHistoryRow: View {
    let record: HistoryPresentationRecord

    var body: some View {
        HStack(spacing: 18) {
            Text(record.timestampText)
                .font(.studioBody(14, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
                .frame(width: 170, alignment: .leading)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(record.accentColor)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: record.accentName)
                            .foregroundStyle(.white)
                    )

                Text(record.sourceName)
                    .font(.studioBody(14, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
            }
            .frame(width: 280, alignment: .leading)

            Text(record.previewText)
                .font(.studioBody(14))
                .italic()
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(StudioTheme.surface)
    }
}

private extension HistoryPresentationRecord {
    var accentColor: Color {
        switch accentColorName {
        case "purple":
            return Color.purple.opacity(0.82)
        case "green":
            return Color.green.opacity(0.82)
        case "orange":
            return Color.orange.opacity(0.82)
        default:
            return StudioTheme.accent
        }
    }
}
