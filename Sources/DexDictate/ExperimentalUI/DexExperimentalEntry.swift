import SwiftUI
import DexDictateKit

/// Container that owns the `DexExperimentalUIStateAdapter` lifecycle and wraps
/// the experimental popover surface. Shown only when
/// `AppSettings.useExperimentalStateFirstUI == true`.
///
/// Using an explicit `init` here is the SwiftUI-idiomatic pattern for
/// injecting dependencies into `@StateObject` — the factory is called once
/// on first appearance.
struct DexExperimentalEntry: View {
    @StateObject private var adapter: DexExperimentalUIStateAdapter

    let engine: TranscriptionEngine
    let permissionManager: PermissionManager
    let settings: AppSettings
    let profileManager: ProfileManager
    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onRequestOnboardingDebug: (() -> Void)?

    init(
        engine: TranscriptionEngine,
        permissionManager: PermissionManager,
        settings: AppSettings,
        profileManager: ProfileManager,
        onDetachHistory: (() -> Void)? = nil,
        onOpenHelp: (() -> Void)? = nil,
        onRequestOnboardingDebug: (() -> Void)? = nil
    ) {
        self.engine = engine
        self.permissionManager = permissionManager
        self.settings = settings
        self.profileManager = profileManager
        self.onDetachHistory = onDetachHistory
        self.onOpenHelp = onOpenHelp
        self.onRequestOnboardingDebug = onRequestOnboardingDebug
        _adapter = StateObject(wrappedValue: DexExperimentalUIStateAdapter(
            engine: engine,
            permissionManager: permissionManager,
            settings: settings,
            profileManager: profileManager
        ))
    }

    var body: some View {
        DexStateFirstPopoverView(
            adapter: adapter,
            settings: settings,
            permissionManager: permissionManager,
            engine: engine,
            profileManager: profileManager,
            onDetachHistory: onDetachHistory,
            onOpenHelp: onOpenHelp,
            onRequestOnboardingDebug: onRequestOnboardingDebug
        )
        // Top-left header controls: quit on the far left, then the UI switch.
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                ChromeIconButton(
                    systemName: "power",
                    accessibilityText: "Quit DexDictate"
                ) {
                    NSApplication.shared.terminate(nil)
                }
                UIModeToggleButton(settings: settings)
            }
            .padding(.top, 8)
            .padding(.leading, 8)
        }
    }
}
