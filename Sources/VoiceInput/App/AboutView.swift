import AppKit
import SwiftUI

struct AboutView: View {
    private let websiteURL = URL(string: "https://github.com/mylxsw")!
    private let projectURL = URL(string: "https://github.com/mylxsw/voice-input")!

    var body: some View {
        ZStack {
            StudioTheme.windowBackground
                .ignoresSafeArea()

            VStack(spacing: StudioTheme.Spacing.xxxLarge) {
                headerSection

                VStack(spacing: StudioTheme.Spacing.medium) {
                    aboutRow(title: "Developer", value: "@mylxsw", link: websiteURL)
                    aboutRow(title: "Website", value: websiteURL.absoluteString, link: websiteURL)
                    aboutRow(
                        title: "Project",
                        value: "Personal macOS menu bar voice input app built with SwiftUI and AppKit.",
                        link: projectURL
                    )
                    aboutRow(title: "Version", value: versionDescription)
                }

                quoteSection

                footerLinks
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        VStack(spacing: StudioTheme.Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.75, blue: 0.14), Color(red: 1.0, green: 0.58, blue: 0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: StudioTheme.Spacing.xSmall) {
                Text("VoiceInput")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                versionBadge
            }
        }
    }

    private var versionBadge: some View {
        HStack(spacing: StudioTheme.Spacing.xSmall) {
            Text(shortVersion)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )

            Button("Project Page") {
                open(projectURL)
            }
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func aboutRow(title: String, value: String, link: URL? = nil) -> some View {
        VStack(alignment: .leading, spacing: StudioTheme.Spacing.xSmall) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.45))

            if let link {
                Button {
                    open(link)
                } label: {
                    HStack(alignment: .top, spacing: StudioTheme.Spacing.small) {
                        Text(value)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.92))
                }
                .buttonStyle(.plain)
            } else {
                Text(value)
                    .foregroundStyle(Color.white.opacity(0.92))
            }
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var quoteSection: some View {
        Text("Speak naturally, write anywhere.")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.white.opacity(0.7))
            .padding(.top, 8)
    }

    private var footerLinks: some View {
        VStack(spacing: StudioTheme.Spacing.medium) {
            HStack(spacing: StudioTheme.Spacing.medium) {
                footerLink(title: "Developer", url: projectURL)
                footerDivider
                footerLink(title: "Website", url: websiteURL)
                footerDivider
                footerLink(title: "Repository", url: projectURL)
            }

            Text("Personal project by @mylxsw")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(.top, 6)
    }

    private var footerDivider: some View {
        Capsule()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 14)
    }

    private func footerLink(title: String, url: URL) -> some View {
        Button(title) {
            open(url)
        }
        .buttonStyle(.plain)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.72))
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
