import AppKit
import SwiftUI

private final class TransparentAskAnswerHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        false
    }
}

final class AskAnswerWindowController: NSObject {
    fileprivate enum Metrics {
        static let windowWidth: CGFloat = 820
        static let windowHeight: CGFloat = 560
        static let minWindowWidth: CGFloat = 680
        static let minWindowHeight: CGFloat = 420
        static let titleBarInsetHeight: CGFloat = 40
        static let outerHorizontalPadding: CGFloat = 24
        static let outerBottomPadding: CGFloat = 18
        static let sectionSpacing: CGFloat = 12
        static let headerButtonSize: CGFloat = 20
        static let contentCardCornerRadius: CGFloat = 12
        static let contentCardPadding: CGFloat = 16
        static let answerContentTopPadding: CGFloat = 6
        static let promptMinHeight: CGFloat = 86
        static let footerHeight: CGFloat = 18
        static let iconBadgeSize: CGFloat = 20
        static let selectedTextMaxLines: Int = 4
    }

    fileprivate enum Palette {
        static let windowBackground = StudioTheme.dynamic(
            light: NSColor(calibratedRed: 0.945, green: 0.962, blue: 0.985, alpha: 0.96),
            dark: NSColor(calibratedRed: 0.060, green: 0.068, blue: 0.084, alpha: 0.94),
        )
        static let windowBackgroundLower = StudioTheme.dynamic(
            light: NSColor(calibratedRed: 0.975, green: 0.982, blue: 0.995, alpha: 0.94),
            dark: NSColor(calibratedRed: 0.078, green: 0.084, blue: 0.105, alpha: 0.92),
        )
        static let promptSurface = StudioTheme.dynamic(
            light: NSColor(calibratedWhite: 1.0, alpha: 0.96),
            dark: NSColor(calibratedRed: 0.115, green: 0.120, blue: 0.155, alpha: 0.94),
        )
        static let answerSurface = StudioTheme.dynamic(
            light: NSColor(calibratedWhite: 1.0, alpha: 0.97),
            dark: NSColor(calibratedRed: 0.105, green: 0.112, blue: 0.145, alpha: 0.95),
        )
        static let cardHighlight = StudioTheme.dynamic(
            light: NSColor(calibratedWhite: 1.0, alpha: 0.74),
            dark: NSColor(calibratedWhite: 1.0, alpha: 0.055),
        )
        static let border = StudioTheme.dynamic(
            light: NSColor(calibratedRed: 0.42, green: 0.50, blue: 0.64, alpha: 0.20),
            dark: NSColor(calibratedWhite: 1.0, alpha: 0.13),
        )
        static let questionAccent = StudioTheme.dynamic(
            light: NSColor(calibratedRed: 0.34, green: 0.42, blue: 0.94, alpha: 1),
            dark: NSColor(calibratedRed: 0.64, green: 0.52, blue: 1.0, alpha: 1),
        )
        static let answerAccent = StudioTheme.dynamic(
            light: NSColor(calibratedRed: 0.11, green: 0.58, blue: 0.39, alpha: 1),
            dark: NSColor(calibratedRed: 0.30, green: 0.82, blue: 0.55, alpha: 1),
        )
    }

    fileprivate final class Model: ObservableObject {
        @Published var question: String = ""
        @Published var selectedText: String = ""
        @Published var answerMarkdown: String = ""
        @Published var appearanceMode: AppearanceMode = .light
        @Published var onPromptCopyRequested: (() -> Void)?
        @Published var onAnswerCopyRequested: (() -> Void)?
    }

    private final class WindowSession {
        let model: Model
        let window: NSWindow
        let hostingView: NSHostingView<AskAnswerWindowView>

        init(model: Model, window: NSWindow, hostingView: NSHostingView<AskAnswerWindowView>) {
            self.model = model
            self.window = window
            self.hostingView = hostingView
        }
    }

    private let clipboard: ClipboardService
    private let settingsStore: SettingsStore

    private var sessions: [ObjectIdentifier: WindowSession] = [:]
    private var appearanceObserver: NSObjectProtocol?

    init(clipboard: ClipboardService, settingsStore: SettingsStore) {
        self.clipboard = clipboard
        self.settingsStore = settingsStore
        super.init()

        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .appearanceModeDidChange,
            object: settingsStore,
            queue: .main,
        ) { [weak self] _ in
            guard let self else { return }
            for session in sessions.values {
                session.model.appearanceMode = self.settingsStore.appearanceMode
                session.hostingView.rootView = AskAnswerWindowView(model: session.model)
                applyAppearance(to: session.window)
            }
        }
    }

    deinit {
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
    }

    func show(title: String, question: String, selectedText: String?, answerMarkdown: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.show(title: title, question: question, selectedText: selectedText, answerMarkdown: answerMarkdown)
            }
            return
        }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSelectedText = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedAnswer = answerMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAnswer.isEmpty else { return }

        let presentationStartedAt = Date()
        let model = Model()
        model.question = trimmedQuestion
        model.selectedText = trimmedSelectedText
        model.answerMarkdown = trimmedAnswer
        model.appearanceMode = settingsStore.appearanceMode
        model.onPromptCopyRequested = { [weak self] in
            let promptText = trimmedSelectedText.isEmpty
                ? trimmedQuestion
                : "\(trimmedQuestion)\n\n\(trimmedSelectedText)"
            self?.clipboard.write(text: promptText)
        }
        model.onAnswerCopyRequested = { [weak self] in
            self?.clipboard.write(text: trimmedAnswer)
        }

        NetworkDebugLogger.logMessage(
            """
            [Ask Answer] Presenting answer window
            Question Length: \(trimmedQuestion.count)
            Question Preview: \(String(trimmedQuestion.prefix(120)))
            Selected Text Length: \(trimmedSelectedText.count)
            Answer Markdown Length: \(trimmedAnswer.count)
            Answer Markdown Preview: \(String(trimmedAnswer.prefix(160)))
            """,
        )

        let session = makeWindowSession(model: model)
        positionNewWindow(session.window, offsetIndex: sessions.count)
        sessions[ObjectIdentifier(session.window)] = session

        DockVisibilityController.shared.windowDidShow(session.window)
        session.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NetworkDebugLogger.logMessage(
            String(
                format: "[Ask Timing] answer window presented in %.1fms",
                Date().timeIntervalSince(presentationStartedAt) * 1_000,
            ),
        )
        _ = title
    }

    func dismiss() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.dismiss() }
            return
        }
        for session in sessions.values {
            DockVisibilityController.shared.windowDidHide(session.window)
            session.window.delegate = nil
            session.window.close()
        }
        sessions.removeAll()
    }

    private func makeWindowSession(model: Model) -> WindowSession {
        let rootView = AskAnswerWindowView(model: model)
        let hosting = TransparentAskAnswerHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.windowWidth, height: Metrics.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
        )

        window.title = L("workflow.ask.answerTitle")
        window.identifier = TypefluxWindowIdentity.askAnswerWindowIdentifier
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.delegate = self
        window.minSize = NSSize(width: Metrics.minWindowWidth, height: Metrics.minWindowHeight)
        window.backgroundColor = NSColor(Palette.windowBackground)
        window.contentView = hosting
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        applyAppearance(to: window)

        return WindowSession(model: model, window: window, hostingView: hosting)
    }

    private func positionNewWindow(_ window: NSWindow, offsetIndex: Int) {
        window.center()

        let cascadeStep = CGFloat((offsetIndex % 8) * 28)
        guard cascadeStep > 0 else { return }

        var frame = window.frame
        frame.origin.x += cascadeStep
        frame.origin.y -= cascadeStep

        if let visibleFrame = window.screen?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        }

        window.setFrameOrigin(frame.origin)
    }

    private func applyAppearance(to window: NSWindow) {
        window.appearance = AppAppearance.nsAppearance(for: settingsStore.appearanceMode)
        window.backgroundColor = NSColor(Palette.windowBackground)
    }
}

extension AskAnswerWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        DockVisibilityController.shared.windowDidHide(window)
        sessions.removeValue(forKey: ObjectIdentifier(window))
    }
}

private struct AskAnswerWindowView: View {
    @ObservedObject var model: AskAnswerWindowController.Model

    @State private var isPromptHovered = false
    @State private var isAnswerHovered = false
    @State private var isSelectedTextExpanded = false

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea(.container, edges: .top)

            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: AskAnswerWindowController.Metrics.titleBarInsetHeight)

                VStack(alignment: .leading, spacing: AskAnswerWindowController.Metrics.sectionSpacing) {
                    promptSection
                    answerSection
                    footer
                }
                .padding(.horizontal, AskAnswerWindowController.Metrics.outerHorizontalPadding)
                .padding(.bottom, AskAnswerWindowController.Metrics.outerBottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(
            minWidth: AskAnswerWindowController.Metrics.minWindowWidth,
            idealWidth: AskAnswerWindowController.Metrics.windowWidth,
            maxWidth: .infinity,
            minHeight: AskAnswerWindowController.Metrics.minWindowHeight,
            idealHeight: AskAnswerWindowController.Metrics.windowHeight,
            maxHeight: .infinity,
        )
        .background(Color.clear)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var background: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            LinearGradient(
                colors: [
                    AskAnswerWindowController.Palette.windowBackground,
                    AskAnswerWindowController.Palette.windowBackgroundLower,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            LinearGradient(
                colors: [
                    StudioTheme.windowHighlight.opacity(0.36),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: StudioTheme.Spacing.large) {
            HStack(alignment: .center) {
                sectionHeader(
                    title: L("workflow.ask.questionSectionTitle"),
                    systemImage: "person.fill",
                    accent: AskAnswerWindowController.Palette.questionAccent,
                )

                Spacer()

                copyButton(isVisible: isPromptHovered) {
                    model.onPromptCopyRequested?()
                }
            }

            VStack(alignment: .leading, spacing: StudioTheme.Spacing.textCompact) {
                HStack(alignment: .firstTextBaseline, spacing: StudioTheme.Spacing.xSmall) {
                    Text(model.question)
                        .font(.studioBody(StudioTheme.Typography.bodyLarge, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !model.selectedText.isEmpty {
                        Image(systemName: isSelectedTextExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: StudioTheme.Typography.iconTiny, weight: .semibold))
                            .foregroundStyle(StudioTheme.textTertiary)
                            .padding(.top, 2)
                    }
                }

                if !model.selectedText.isEmpty {
                    Text(model.selectedText)
                        .font(.studioBody(StudioTheme.Typography.bodySmall, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .lineLimit(isSelectedTextExpanded ? nil : AskAnswerWindowController.Metrics.selectedTextMaxLines)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, StudioTheme.Spacing.small)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(AskAnswerWindowController.Palette.questionAccent.opacity(0.55))
                                .frame(width: 3)
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !model.selectedText.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.16)) {
                    isSelectedTextExpanded.toggle()
                }
            }
        }
        .padding(AskAnswerWindowController.Metrics.contentCardPadding)
        .frame(maxWidth: .infinity, minHeight: AskAnswerWindowController.Metrics.promptMinHeight, alignment: .topLeading)
        .background(cardBackground(fill: AskAnswerWindowController.Palette.promptSurface))
        .overlay(cardBorder)
        .contentShape(Rectangle())
        .onHover { isPromptHovered = $0 }
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: StudioTheme.Spacing.large) {
            HStack(alignment: .center) {
                sectionHeader(
                    title: L("workflow.ask.answerSectionTitle"),
                    systemImage: "sparkles",
                    accent: AskAnswerWindowController.Palette.answerAccent,
                )

                Spacer()

                copyButton(isVisible: isAnswerHovered) {
                    model.onAnswerCopyRequested?()
                }
            }

            MarkdownWebView(
                markdown: model.answerMarkdown,
                appearanceMode: model.appearanceMode,
            )
            .padding(.top, AskAnswerWindowController.Metrics.answerContentTopPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(AskAnswerWindowController.Metrics.contentCardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground(fill: AskAnswerWindowController.Palette.answerSurface))
        .overlay(cardBorder)
        .contentShape(RoundedRectangle(
            cornerRadius: AskAnswerWindowController.Metrics.contentCardCornerRadius,
            style: .continuous,
        ))
        .onHover { isAnswerHovered = $0 }
    }

    private var footer: some View {
        HStack(spacing: StudioTheme.Spacing.xxSmall) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: StudioTheme.Typography.caption, weight: .semibold))
            Text(L("workflow.ask.answerDisclaimer"))
                .font(.studioBody(StudioTheme.Typography.caption, weight: .medium))
        }
        .foregroundStyle(StudioTheme.textTertiary.opacity(0.74))
        .frame(maxWidth: .infinity)
        .frame(height: AskAnswerWindowController.Metrics.footerHeight)
    }

    private func sectionHeader(title: String, systemImage: String, accent: Color) -> some View {
        HStack(spacing: StudioTheme.Spacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: StudioTheme.Typography.iconXSmall, weight: .bold))
                .foregroundStyle(accent)
                .frame(
                    width: AskAnswerWindowController.Metrics.iconBadgeSize,
                    height: AskAnswerWindowController.Metrics.iconBadgeSize,
                )
                .background(Circle().fill(accent.opacity(0.14)))

            Text(title)
                .font(.studioBody(StudioTheme.Typography.bodyLarge, weight: .bold))
                .foregroundStyle(accent)
        }
    }

    private func cardBackground(fill: Color) -> some View {
        RoundedRectangle(
            cornerRadius: AskAnswerWindowController.Metrics.contentCardCornerRadius,
            style: .continuous,
        )
        .fill(fill)
        .overlay(alignment: .top) {
            RoundedRectangle(
                cornerRadius: AskAnswerWindowController.Metrics.contentCardCornerRadius,
                style: .continuous,
            )
            .fill(
                LinearGradient(
                    colors: [
                        AskAnswerWindowController.Palette.cardHighlight,
                        Color.clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom,
                ),
            )
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(
            cornerRadius: AskAnswerWindowController.Metrics.contentCardCornerRadius,
            style: .continuous,
        )
        .stroke(AskAnswerWindowController.Palette.border, lineWidth: 1)
    }

    private func copyButton(isVisible: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: StudioTheme.Typography.iconXSmall, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(
                    width: AskAnswerWindowController.Metrics.headerButtonSize,
                    height: AskAnswerWindowController.Metrics.headerButtonSize,
                )
        }
        .buttonStyle(.plain)
        .studioTooltip(L("common.copy"), yOffset: 30)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeOut(duration: 0.12), value: isVisible)
    }
}
