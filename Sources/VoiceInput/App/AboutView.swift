import AppKit
import SwiftUI

struct AboutView: View {
    let appearanceMode: AppearanceMode

    private let websiteURL = URL(string: "https://github.com/mylxsw")!
    private let projectURL = URL(string: "https://github.com/mylxsw/voice-input")!

    var body: some View {
        ZStack {
            StudioTheme.windowBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: StudioTheme.Spacing.pageGroup) {
                    headerCard
                    detailsCard
                    linksCard
                }
                .padding(StudioTheme.Insets.cardDefault)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var headerCard: some View {
        StudioCard {
            HStack(alignment: .top, spacing: StudioTheme.Spacing.large) {
                ZStack {
                    RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.hero, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.92, green: 0.96, blue: 1.00),
                                    Color(red: 0.84, green: 0.91, blue: 1.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 84)

                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(StudioTheme.accent)
                }

                VStack(alignment: .leading, spacing: StudioTheme.Spacing.small) {
                    Text("About")
                        .font(.studioBody(StudioTheme.Typography.caption, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)

                    Text("VoiceInput")
                        .font(.studioDisplay(StudioTheme.Typography.heroTitle, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)

                    Text("A personal macOS menu bar voice input app by @mylxsw.")
                        .font(.studioBody(StudioTheme.Typography.bodyLarge))
                        .foregroundStyle(StudioTheme.textSecondary)

                    HStack(spacing: StudioTheme.Spacing.small) {
                        StudioPill(title: "Version \(versionDescription)")
                        StudioPill(
                            title: appearanceMode.displayName,
                            tone: StudioTheme.accent,
                            fill: StudioTheme.accentSoft
                        )
                    }
                }

                Spacer()
            }
        }
    }

    private var detailsCard: some View {
        StudioCard {
            StudioSectionTitle(title: "DETAILS")

            detailRow(
                icon: "person.crop.circle",
                title: "Developer",
                value: "@mylxsw",
                subtitle: "Independent developer"
            )

            divider

            detailLinkRow(
                icon: "globe",
                title: "Website",
                value: "github.com/mylxsw",
                subtitle: websiteURL.absoluteString,
                url: websiteURL
            )

            divider

            detailLinkRow(
                icon: "shippingbox",
                title: "Project",
                value: "voice-input",
                subtitle: "Source code, issues, and release history",
                url: projectURL
            )

            divider

            detailRow(
                icon: "number",
                title: "Build",
                value: versionDescription,
                subtitle: "Read from the app bundle"
            )
        }
    }

    private var linksCard: some View {
        StudioCard {
            StudioSectionTitle(title: "LINKS")

            Text("Use the links below to visit the repository or developer profile.")
                .font(.studioBody(StudioTheme.Typography.bodyLarge))
                .foregroundStyle(StudioTheme.textSecondary)

            HStack(spacing: StudioTheme.Spacing.smallMedium) {
                StudioButton(title: "Open Website", systemImage: "globe", variant: .secondary) {
                    open(websiteURL)
                }

                StudioButton(title: "Open Repository", systemImage: "arrow.up.right.square", variant: .primary) {
                    open(projectURL)
                }
            }

            Text("Speak naturally, write anywhere.")
                .font(.studioDisplay(StudioTheme.Typography.sectionTitle, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)
        }
    }

    private func detailRow(icon: String, title: String, value: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: StudioTheme.Spacing.medium) {
            detailIcon(icon)

            VStack(alignment: .leading, spacing: StudioTheme.Spacing.xxxSmall) {
                Text(title)
                    .font(.studioBody(StudioTheme.Typography.caption, weight: .semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                Text(value)
                    .font(.studioBody(StudioTheme.Typography.settingTitle, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(subtitle)
                    .font(.studioBody(StudioTheme.Typography.body))
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            Spacer()
        }
    }

    private func detailLinkRow(icon: String, title: String, value: String, subtitle: String, url: URL) -> some View {
        Button {
            open(url)
        } label: {
            HStack(alignment: .center, spacing: StudioTheme.Spacing.medium) {
                detailIcon(icon)

                VStack(alignment: .leading, spacing: StudioTheme.Spacing.xxxSmall) {
                    Text(title)
                        .font(.studioBody(StudioTheme.Typography.caption, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)
                    Text(value)
                        .font(.studioBody(StudioTheme.Typography.settingTitle, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(subtitle)
                        .font(.studioBody(StudioTheme.Typography.body))
                        .foregroundStyle(StudioTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: StudioTheme.Typography.iconXSmall, weight: .semibold))
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StudioInteractiveButtonStyle())
    }

    private func detailIcon(_ icon: String) -> some View {
        RoundedRectangle(cornerRadius: StudioTheme.CornerRadius.medium, style: .continuous)
            .fill(StudioTheme.accentSoft)
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: StudioTheme.Typography.iconRegular, weight: .semibold))
                    .foregroundStyle(StudioTheme.accent)
            )
    }

    private var divider: some View {
        Rectangle()
            .fill(StudioTheme.border.opacity(StudioTheme.Opacity.divider))
            .frame(height: 1)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var versionDescription: String {
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let buildVersion, buildVersion != shortVersion {
            return "\(shortVersion) (\(buildVersion))"
        }
        return shortVersion
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
