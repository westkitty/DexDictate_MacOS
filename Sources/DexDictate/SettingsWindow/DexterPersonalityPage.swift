import SwiftUI
import AppKit
import DexDictateKit

/// Settings → Dexter & Personality. The only page that touches Dexter identity
/// presentation — reads `ProfileManager`'s existing published state and calls its
/// existing API only (`selectProfile`, `refreshDynamicContent`). Ticker marquee
/// logic/timing (`FlavorTickerView.swift`), watermark selection/randomization
/// (`WatermarkAssetProvider.swift`), and profile state logic (`ProfileManager.swift`)
/// are untouched — this page only surfaces existing controls in a new location.
///
/// `profileManager` must be the app's single existing instance (not a fresh one) so a
/// profile switch made here is immediately visible in the popover's ticker/watermark.
struct DexterPersonalityPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var profileManager: ProfileManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(SettingsPage.dexterPersonality.title)
                    .font(.title2.bold())

                Text("Profile")
                    .font(.headline)
                profileCards

                Divider()

                Text("Theme")
                    .font(.headline)
                HStack {
                    Text("Appearance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $settings.appearanceTheme) {
                        ForEach(AppSettings.AppearanceTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                Divider()

                Text("Ticker")
                    .font(.headline)
                Toggle("Show Flavor Ticker", isOn: $settings.showFlavorTicker)
                Toggle("Animate Flavor Ticker", isOn: $settings.animateFlavorTicker)
                Text("Ticker motion still yields to macOS Reduce Motion even when animation stays enabled here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Inline Result Quotes")
                    .font(.headline)
                Toggle("Show quote inline with results", isOn: .constant(false))
                    .disabled(true)
                Text("Coming with experimental adoption (Packet 12A).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Watermark Backdrop")
                    .font(.headline)
                if let asset = profileManager.currentWatermarkAsset, let nsImage = NSImage(contentsOf: asset.url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .opacity(0.5)
                }
                Button("Shuffle Now") {
                    profileManager.refreshDynamicContent()
                }
                .buttonStyle(.bordered)
                Text("Rotates the ticker line and watermark image together — there's no separate watermark-only refresh in the underlying API.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var profileCards: some View {
        HStack(spacing: 12) {
            ForEach(AppProfile.allCases) { profile in
                profileCard(for: profile)
            }
        }
    }

    private func profileCard(for profile: AppProfile) -> some View {
        let isActive = profileManager.activeProfile == profile
        let thumbnail = profileManager.watermarkAssets(for: profile).first.flatMap { NSImage(contentsOf: $0.url) }

        return Button {
            profileManager.selectProfile(profile)
        } label: {
            VStack(spacing: 8) {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 48, height: 48)

                Text(profile.title)
                    .font(.caption.weight(.semibold))
            }
            .padding(12)
            .frame(width: 100)
            .background(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(profile.title) profile\(isActive ? ", active" : "")")
    }
}
