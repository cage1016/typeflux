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

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 92),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isOpaque = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            panel.contentView = hosting

            window = panel
        }

        positionWindow()
        window?.orderFrontRegardless()
        model.statusText = "正在输入中"
    }

    func showProcessing() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.showProcessing() }
            return
        }
        show()
        model.statusText = "转写中"
    }

    func showFailure(message: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.showFailure(message: message) }
            return
        }
        show()
        model.statusText = "失败"
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
        model.detailText = text
    }

    func dismissSoon() {
        dismiss(after: 0.4)
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
        let size = window.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.minY + 80
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

final class OverlayViewModel: ObservableObject {
    @Published var statusText: String = ""
    @Published var detailText: String = ""
    @Published var level: Float = 0
}

private struct OverlayView: View {
    @ObservedObject var model: OverlayViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.statusText)
                        .font(.headline)
                    if !model.detailText.isEmpty {
                        Text(model.detailText)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                LevelBar(level: model.level)
                    .frame(width: 56, height: 12)
            }
            .padding(14)
        }
        .frame(width: 320, height: 92)
    }
}

private struct LevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.7))
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, level))))
            }
        }
    }
}
