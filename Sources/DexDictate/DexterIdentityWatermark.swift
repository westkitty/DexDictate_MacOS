import SwiftUI
import AppKit
import DexDictateKit

/// Shared Dexter identity watermark used behind Settings and Guide pages.
///
/// Why this exists: the menu-bar popover (`AntiGravityMainView`) has always carried a
/// low-opacity Dexter image behind its content, but the Settings window (packets 02–15)
/// and the Help window were built/migrated without it, leaving them looking like a generic
/// settings utility. This view re-establishes the Dexter identity behind every page from a
/// single reusable source so it never has to be duplicated per page.
///
/// Interaction safety: this view is purely decorative. It sets `.allowsHitTesting(false)`
/// so it can never intercept clicks, toggles, scrolling, sheets, popovers, or keyboard
/// focus, and it is always placed *behind* page content (as the bottom of a `ZStack` or via
/// `.background`), never as an overlay.
struct DexterIdentityWatermark: View {
    /// Optional profile-driven asset (e.g. `profileManager.currentWatermarkAsset?.url`) so
    /// the watermark matches the popover's current Dexter image and respects the active
    /// regional profile. When `nil`, a stable bundled Dexter image is used instead.
    var assetURL: URL? = nil

    /// Low by default so dense forms and help text stay fully legible. Callers can nudge it
    /// but should keep it subtle.
    var opacity: Double = 0.06

    /// Rendered size of the mark. Large enough to read as identity, centered in the pane.
    var size: CGFloat = 360

    var body: some View {
        Group {
            if let image = Self.resolvedImage(assetURL: assetURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .opacity(opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Image resolution (cached)

    /// Cache keyed by resolved source so we never re-read PNGs from disk on body re-renders.
    private static var cache: [String: NSImage] = [:]

    /// Stable Dexter identity image guaranteed to ship in the DexDictateKit resource bundle
    /// (same flat ProfileAssets PNG the `WatermarkAssetProvider` pool draws from). Used as
    /// the fallback whenever no profile-driven asset URL is supplied or resolvable.
    private static let fallbackResourceName = "DexDictate_app_settings"

    private static func resolvedImage(assetURL: URL?) -> NSImage? {
        if let assetURL {
            let key = assetURL.absoluteString
            if let cached = cache[key] { return cached }
            if let image = NSImage(contentsOf: assetURL) {
                cache[key] = image
                return image
            }
        }

        if let cached = cache[fallbackResourceName] { return cached }
        if let url = Safety.resourceBundle.url(forResource: fallbackResourceName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            cache[fallbackResourceName] = image
            return image
        }
        return nil
    }
}
