import SwiftUI

enum FeedbackImageUploadState: Equatable {
    case preparing
    case uploading
    case uploaded(String)
    case failed(String)

    var isReady: Bool {
        if case .uploaded = self { return true }
        return false
    }

    var isInProgress: Bool {
        switch self {
        case .preparing, .uploading:
            return true
        case .uploaded, .failed:
            return false
        }
    }

    var uploadedURL: String? {
        if case .uploaded(let url) = self { return url }
        return nil
    }
}

struct FeedbackImageAttachment: Identifiable {
    let id: UUID
    var filename: String
    var thumbnail: NSImage?
    var state: FeedbackImageUploadState

    init(
        id: UUID = UUID(),
        filename: String,
        thumbnail: NSImage? = nil,
        state: FeedbackImageUploadState
    ) {
        self.id = id
        self.filename = filename
        self.thumbnail = thumbnail
        self.state = state
    }
}

struct DirectFeedbackSheet: View {
    @Binding var content: String
    @Binding var contact: String
    @Binding var images: [FeedbackImageAttachment]
    let isSubmitting: Bool
    let errorMessage: String?
    let onAddImages: () -> Void
    let onRemoveImage: (FeedbackImageAttachment.ID) -> Void
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isContentFocused: Bool

    private let contentEditorPadding: CGFloat = 10
    private let contentPlaceholderHorizontalPadding: CGFloat = 13
    private let contentPlaceholderVerticalPadding: CGFloat = 15

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedContent.isEmpty
            && !images.contains { $0.state.isInProgress }
            && !images.contains {
                if case .failed = $0.state { return true }
                return false
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioTheme.Spacing.mediumLarge) {
            Text(L("feedback.direct.title"))
                .font(.studioDisplay(20, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            VStack(alignment: .leading, spacing: StudioTheme.Spacing.small) {
                Text(L("feedback.direct.contentLabel"))
                    .font(.studioBody(12, weight: .semibold))
                    .foregroundStyle(StudioTheme.textSecondary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $content)
                        .font(.studioBody(13))
                        .scrollContentBackground(.hidden)
                        .padding(contentEditorPadding)
                        .frame(minHeight: 160)
                        .background(StudioTheme.controlSurface)
                        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous)
                                .stroke(StudioTheme.border.opacity(0.72), lineWidth: 1)
                        }
                        .focused($isContentFocused)

                    if content.isEmpty {
                        Text(L("feedback.direct.contentPlaceholder"))
                            .font(.studioBody(13))
                            .foregroundStyle(StudioTheme.textTertiary)
                            .padding(.horizontal, contentPlaceholderHorizontalPadding)
                            .padding(.vertical, contentPlaceholderVerticalPadding)
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsHitTesting(false)
                    }
                }
            }

            VStack(alignment: .leading, spacing: StudioTheme.Spacing.small) {
                HStack {
                    Text(L("feedback.direct.imagesLabel"))
                        .font(.studioBody(12, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)

                    Spacer()

                    Button(action: onAddImages) {
                        Label(L("feedback.direct.addImage"), systemImage: "plus")
                    }
                    .disabled(isSubmitting || images.count >= 4)
                }

                if !images.isEmpty {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(68), spacing: StudioTheme.Spacing.small),
                            count: 4
                        ),
                        alignment: .leading,
                        spacing: StudioTheme.Spacing.small
                    ) {
                        ForEach(images) { image in
                            FeedbackImageThumbnail(
                                image: image,
                                onRemove: { onRemoveImage(image.id) }
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: StudioTheme.Spacing.small) {
                Text(L("feedback.direct.contactLabel"))
                    .font(.studioBody(12, weight: .semibold))
                    .foregroundStyle(StudioTheme.textSecondary)

                TextField(L("feedback.direct.contactPlaceholder"), text: $contact)
                    .textFieldStyle(.plain)
                    .font(.studioBody(13))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(StudioTheme.controlSurface)
                    .clipShape(RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous)
                            .stroke(StudioTheme.border.opacity(0.72), lineWidth: 1)
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.studioBody(12))
                    .foregroundStyle(StudioTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()

                Button(L("common.cancel"), action: onCancel)
                    .disabled(isSubmitting)

                Button {
                    onSubmit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(L("feedback.direct.submit"))
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSubmitting || !canSubmit)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            isContentFocused = true
        }
    }
}

private struct FeedbackImageThumbnail: View {
    let image: FeedbackImageAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous)
                    .fill(StudioTheme.controlSurface)

                if let thumbnail = image.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(StudioTheme.textTertiary)
                }

                statusOverlay
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous)
                    .stroke(StudioTheme.border.opacity(0.72), lineWidth: 1)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(StudioTheme.textPrimary, StudioTheme.surface.opacity(0.92))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel(L("feedback.direct.removeImage"))
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch image.state {
        case .preparing, .uploading:
            Rectangle()
                .fill(.black.opacity(0.32))
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                }
        case .uploaded:
            EmptyView()
        case .failed:
            Rectangle()
                .fill(StudioTheme.danger.opacity(0.76))
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                }
        }
    }
}
