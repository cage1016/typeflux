import AppKit
import SwiftUI

final class OverlayController {
    private let appState: AppStateStore
    private var window: NSPanel?

    private let model = OverlayViewModel()

    init(appState: AppStateStore) {
        self.appState = appState
    }

    func show() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.show() }
            return
        }
        if window == nil {
            let view = OverlayView(model: model)
            let hosting = NSHostingView(rootView: view)
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let panel = NSPanel(contentRect: screenFrame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isOpaque = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            panel.contentView = hosting

            window = panel
        }

        positionWindow()
        window?.orderFrontRegardless()
        model.presentation = .recording
        model.statusText = "正在聆听"
        model.detailText = ""
    }

    func showProcessing() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.showProcessing() }
            return
        }
        show()
        model.presentation = .processing
        model.statusText = "Thinking"
        model.detailText = ""
    }

    func showFailure(message: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.showFailure(message: message) }
            return
        }
        show()
        model.presentation = .failure
        model.statusText = "处理失败"
        model.detailText = message
    }

    func updateLevel(_ level: Float) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.updateLevel(level) }
            return
        }
        model.level = level
    }

    func updateStreamingText(_ text: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.updateStreamingText(text) }
            return
        }
        model.presentation = text.contains("已复制到剪贴板") ? .notice : .transcriptPreview
        model.detailText = text
    }

    func dismissSoon() {
        dismiss(after: StudioTheme.Durations.overlayDismissDelay)
    }

    func dismiss(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.window?.orderOut(nil)
            self?.model.detailText = ""
            self?.model.level = 0
        }
    }

    private func positionWindow() {
        guard let screen = NSScreen.main, let window else { return }
        let frame = screen.visibleFrame
        window.setFrame(frame, display: false)
    }
}

final class OverlayViewModel: ObservableObject {
    enum Presentation {
        case recording
        case processing
        case transcriptPreview
        case notice
        case failure
    }

    @Published var presentation: Presentation = .recording
    @Published var statusText: String = ""
    @Published var detailText: String = ""
    @Published var level: Float = 0
}

private struct OverlayView: View {
    @ObservedObject var model: OverlayViewModel

    var body: some View {
        ZStack {
            switch model.presentation {
            case .recording:
                VStack {
                    Spacer()
                    recordingCapsule
                }
                .padding(.bottom, 42)

            case .processing:
                VStack {
                    Spacer()
                    processingCapsule
                }
                .padding(.bottom, 42)

            case .transcriptPreview:
                VStack {
                    previewCard
                    Spacer()
                }
                .padding(.top, 118)

            case .notice:
                VStack {
                    Spacer()
                    noticeToast
                }
                .padding(.bottom, 108)

            case .failure:
                VStack {
                    failureCard
                    Spacer()
                }
                .padding(.top, 88)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var recordingCapsule: some View {
        OverlayCapsule {
            LevelWaveform(level: model.level, activeColor: Color.white.opacity(0.95))
                .frame(width: 42, height: 16)
        }
    }

    private var processingCapsule: some View {
        OverlayCapsule(horizontalPadding: 22) {
            Text(model.statusText.isEmpty ? "Thinking" : model.statusText)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }

    private var previewCard: some View {
        OverlayCard(width: 512) {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "info.circle", accent: Color(red: 0.43, green: 0.56, blue: 1.0), title: "最新转写")

                Text("“\(model.detailText)”")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    OverlayButton(title: "Copy")
                    Spacer()
                }
            }
        }
    }

    private var failureCard: some View {
        OverlayCard(width: 464) {
            VStack(alignment: .leading, spacing: 18) {
                cardHeader(icon: "exclamationmark.circle", accent: Color(red: 1.0, green: 0.42, blue: 0.08), title: model.statusText)

                Text(model.detailText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    OverlayButton(title: "Retry")
                    Spacer()
                }
            }
        }
    }

    private var noticeToast: some View {
        OverlayCard(width: 420, compact: true) {
            HStack(spacing: 14) {
                Image(systemName: "info.circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color(red: 0.43, green: 0.56, blue: 1.0))

                Text(model.detailText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)

                Spacer(minLength: 8)

                OverlayButton(title: "OK", compact: true)
            }
        }
    }

    private func cardHeader(icon: String, accent: Color, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(accent)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))

            Spacer(minLength: 0)

            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }
}

private struct OverlayCapsule<Content: View>: View {
    let horizontalPadding: CGFloat
    @ViewBuilder var content: Content

    init(horizontalPadding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.horizontalPadding = horizontalPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.88))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 12)
    }
}

private struct OverlayCard<Content: View>: View {
    let width: CGFloat
    let compact: Bool
    @ViewBuilder var content: Content

    init(width: CGFloat, compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.width = width
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, compact ? 18 : 26)
            .padding(.vertical, compact ? 14 : 24)
            .frame(width: width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                    .fill(Color(red: 0.13, green: 0.11, blue: 0.11).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.32), radius: 26, x: 0, y: 16)
    }
}

private struct OverlayButton: View {
    let title: String
    let compact: Bool

    init(title: String, compact: Bool = false) {
        self.title = title
        self.compact = compact
    }

    var body: some View {
        Text(title)
            .font(.system(size: compact ? 14 : 15, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.96))
            .padding(.horizontal, compact ? 16 : 22)
            .padding(.vertical, compact ? 10 : 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.14))
            )
    }
}

private struct LevelWaveform: View {
    let level: Float
    let activeColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(activeColor)
                    .frame(width: 2.6, height: barHeight(for: index))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(max(0.08, min(1.0, level)))
        let profile: [CGFloat] = [0.34, 0.52, 0.72, 0.9, 1.0, 0.86, 0.7, 0.5, 0.32]
        return 5 + (12 * normalizedLevel * profile[index])
    }
}
