import AppKit
import SwiftUI

@MainActor
final class StatusBarMenuViewModel: ObservableObject {
    @Published var status: AppStatus
    @Published var appearanceMode: AppearanceMode

    private let settingsStore: SettingsStore
    private let openSection: (StudioSection) -> Void
    private let quitAction: () -> Void

    init(
        status: AppStatus,
        appearanceMode: AppearanceMode,
        settingsStore: SettingsStore,
        openSection: @escaping (StudioSection) -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.status = status
        self.appearanceMode = appearanceMode
        self.settingsStore = settingsStore
        self.openSection = openSection
        self.quitAction = quitAction
    }

    var statusTitle: String {
        switch status {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .failed:
            return "Needs attention"
        }
    }

    var statusSubtitle: String {
        switch status {
        case .idle:
            return "Press your hotkey to start dictation."
        case .recording:
            return "VoiceInput is capturing audio now."
        case .processing:
            return "Transcribing your latest capture."
        case .failed(let message):
            return message
        }
    }

    var statusTint: Color {
        switch status {
        case .idle:
            return StudioTheme.accent
        case .recording:
            return StudioTheme.danger
        case .processing:
            return StudioTheme.warning
        case .failed:
            return StudioTheme.danger
        }
    }

    var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, bundleVersion) {
        case let (version?, bundleVersion?) where version != bundleVersion:
            return "Version \(version) (\(bundleVersion))"
        case let (version?, _):
            return "Version \(version)"
        case let (_, bundleVersion?):
            return "Build \(bundleVersion)"
        default:
            return "VoiceInput"
        }
    }

    func open(_ section: StudioSection) {
        openSection(section)
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        settingsStore.appearanceMode = mode
    }

    func quit() {
        quitAction()
    }

    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private enum StatusBarSubmenu: Hashable {
    case appearance
}

private struct StatusBarRowFrameKey: PreferenceKey {
    static var defaultValue: [StatusBarSubmenu: CGRect] = [:]

    static func reduce(value: inout [StatusBarSubmenu: CGRect], nextValue: () -> [StatusBarSubmenu: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct StatusBarMenuPopoverView: View {
    @ObservedObject var viewModel: StatusBarMenuViewModel
    let dismiss: () -> Void

    @State private var activeSubmenu: StatusBarSubmenu?
    @State private var rowFrames: [StatusBarSubmenu: CGRect] = [:]

    private let panelWidth: CGFloat = 286
    private let submenuWidth: CGFloat = 238
    private let panelSpacing: CGFloat = 14

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            mainPanel

            if activeSubmenu == .appearance {
                submenuPanel
                    .frame(width: submenuWidth)
                    .offset(
                        x: panelWidth + panelSpacing,
                        y: max(24, (rowFrames[.appearance]?.minY ?? 132) - 8)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topLeading)))
            }
        }
        .frame(width: panelWidth + submenuWidth + panelSpacing, alignment: .leading)
        .coordinateSpace(name: "StatusBarMenu")
        .onPreferenceChange(StatusBarRowFrameKey.self) { rowFrames = $0 }
        .preferredColorScheme(viewModel.preferredColorScheme)
        .padding(12)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
            divider

            Group {
                actionRow(
                    title: "Open Voice Studio",
                    symbol: "square.grid.2x2.fill",
                    action: {
                        dismiss()
                        viewModel.open(.home)
                    }
                )

                actionRow(
                    title: "History",
                    symbol: "clock.arrow.circlepath",
                    action: {
                        dismiss()
                        viewModel.open(.history)
                    }
                )
            }

            divider

            Group {
                actionRow(
                    title: "Personas",
                    symbol: "face.smiling",
                    action: {
                        dismiss()
                        viewModel.open(.personas)
                    }
                )

                submenuRow(
                    title: "Appearance",
                    symbol: "circle.lefthalf.filled",
                    submenu: .appearance
                )

                actionRow(
                    title: "Settings",
                    symbol: "gearshape.fill",
                    shortcut: "⌘,",
                    action: {
                        dismiss()
                        viewModel.open(.settings)
                    }
                )
            }

            divider

            Text(viewModel.versionText)
                .font(.studioBody(13, weight: .medium))
                .foregroundStyle(StudioTheme.textTertiary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            divider

            actionRow(
                title: "Quit VoiceInput",
                symbol: "power",
                shortcut: "⌘Q",
                role: .destructive,
                action: {
                    dismiss()
                    viewModel.quit()
                }
            )
        }
        .frame(width: panelWidth, alignment: .leading)
        .background(menuPanelBackground)
    }

    private var statusHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(viewModel.statusTint.opacity(0.18))
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(viewModel.statusTint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.statusTitle)
                    .font(.studioDisplay(17, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                Text(viewModel.statusSubtitle)
                    .font(.studioBody(13))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private var submenuPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.setAppearanceMode(mode)
                    activeSubmenu = nil
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.appearanceMode == mode ? "checkmark" : "circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(viewModel.appearanceMode == mode ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                            .frame(width: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(.studioBody(14, weight: .semibold))
                                .foregroundStyle(StudioTheme.textPrimary)
                            Text(appearanceSummary(for: mode))
                                .font(.studioBody(12))
                                .foregroundStyle(StudioTheme.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(viewModel.appearanceMode == mode ? StudioTheme.accent.opacity(0.9) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(viewModel.appearanceMode == mode ? Color.clear : StudioTheme.border.opacity(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.appearanceMode == mode ? Color.white : StudioTheme.textPrimary)
            }
        }
        .padding(10)
        .background(menuPanelBackground)
    }

    private func actionRow(
        title: String,
        symbol: String,
        shortcut: String? = nil,
        role: StatusBarMenuRowRole = .standard,
        action: @escaping () -> Void
    ) -> some View {
        StatusBarActionRow(
            title: title,
            symbol: symbol,
            shortcut: shortcut,
            role: role,
            showsChevron: false,
            isActive: false,
            onHoverChanged: { isHovering in
                if isHovering {
                    activeSubmenu = nil
                }
            },
            action: action
        )
    }

    private func submenuRow(
        title: String,
        symbol: String,
        submenu: StatusBarSubmenu
    ) -> some View {
        StatusBarActionRow(
            title: title,
            symbol: symbol,
            shortcut: nil,
            role: .standard,
            showsChevron: true,
            isActive: activeSubmenu == submenu,
            onHoverChanged: { isHovering in
                if isHovering {
                    activeSubmenu = submenu
                }
            },
            action: {
                activeSubmenu = activeSubmenu == submenu ? nil : submenu
            }
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: StatusBarRowFrameKey.self,
                    value: [submenu: proxy.frame(in: .named("StatusBarMenu"))]
                )
            }
        )
    }

    private func appearanceSummary(for mode: AppearanceMode) -> String {
        switch mode {
        case .system:
            return "Follow macOS appearance automatically."
        case .light:
            return "Keep the studio surfaces bright."
        case .dark:
            return "Use darker panels and chrome."
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(StudioTheme.border.opacity(0.56))
            .frame(height: 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    private var menuPanelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(StudioTheme.border.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 22, x: 0, y: 14)
    }
}

private enum StatusBarMenuRowRole {
    case standard
    case destructive
}

private struct StatusBarActionRow: View {
    let title: String
    let symbol: String
    let shortcut: String?
    let role: StatusBarMenuRowRole
    let showsChevron: Bool
    let isActive: Bool
    let onHoverChanged: (Bool) -> Void
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 16)

                Text(title)
                    .font(.studioBody(15, weight: .semibold))

                Spacer(minLength: 0)

                if let shortcut {
                    Text(shortcut)
                        .font(.studioMono(12, weight: .medium))
                        .foregroundStyle(foreground.opacity(0.72))
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(foreground.opacity(0.86))
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHighlighted ? StudioTheme.accent.opacity(0.94) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovering = hovering
            onHoverChanged(hovering)
        }
    }

    private var isHighlighted: Bool {
        isHovering || isActive
    }

    private var foreground: Color {
        if isHighlighted {
            return .white
        }

        switch role {
        case .standard:
            return StudioTheme.textPrimary
        case .destructive:
            return StudioTheme.danger
        }
    }
}
