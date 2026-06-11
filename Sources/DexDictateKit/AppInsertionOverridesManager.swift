import Foundation
import AppKit

/// The text insertion strategy to use for a specific app.
public enum InsertionModeOverride: String, Codable, CaseIterable, Identifiable {
    case useGlobal = "Use Global Setting"
    case clipboardPaste = "Clipboard Paste (Cmd+V)"
    case clipboardOnly = "Clipboard Only (no paste)"
    case accessibilityAPI = "Accessibility API"
    /// Selects all text in the focused field (Cmd+A) then pastes (Cmd+V).
    /// Use for search bars, address bars, and single-field inputs where each
    /// utterance should replace the whole field contents. Not for documents,
    /// chat boxes, code editors, or multi-line text areas.
    case replaceFieldWithClipboardPaste = "Replace Field with Clipboard Paste"

    public var id: String { rawValue }
}

/// A per-application text insertion override.
public struct AppInsertionOverride: Identifiable, Codable {
    public var id: UUID
    public var bundleID: String
    public var displayName: String
    public var mode: InsertionModeOverride

    public init(id: UUID = UUID(), bundleID: String, displayName: String, mode: InsertionModeOverride) {
        self.id = id
        self.bundleID = bundleID
        self.displayName = displayName
        self.mode = mode
    }
}

/// Manages per-application text insertion overrides.
///
/// Stored as JSON in UserDefaults under `"appInsertionOverrides_v1"`.
public final class AppInsertionOverridesManager: ObservableObject {
    @Published public var overrides: [AppInsertionOverride] = [] {
        didSet { if !isLoading { save() } }
    }

    private let storageKey = "appInsertionOverrides_v1"
    private var isLoading = false

    public init() { load() }

    /// Returns the effective insertion mode for the given bundle ID.
    /// Returns `nil` if no override is configured (caller should use global setting).
    public func effectiveMode(for bundleID: String) -> InsertionModeOverride? {
        guard let override = overrides.first(where: { $0.bundleID == bundleID }),
              override.mode != .useGlobal else { return nil }
        return override.mode
    }

    public func add(_ override: AppInsertionOverride) {
        overrides.removeAll { $0.bundleID == override.bundleID }
        overrides.append(override)
    }

    public func remove(id: UUID) {
        overrides.removeAll { $0.id == id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([AppInsertionOverride].self, from: data)
            isLoading = true
            defer { isLoading = false }
            overrides = decoded
        } catch {
            Safety.log("[AppInsertionOverridesManager] Corrupt data for key '\(storageKey)': \(error). Leaving overrides empty; stored data preserved.", category: .settings)
        }
    }
}
