import SwiftUI
import AppKit
import DexDictateKit

/// Modal window content for configuring per-application text insertion modes.
struct PerAppInsertionView: View {
    @ObservedObject var manager: AppInsertionOverridesManager

    @State private var newBundleID: String = ""
    @State private var newDisplayName: String = ""
    @State private var newMode: InsertionModeOverride = .clipboardPaste
    @State private var showAddRow: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Per-App Insertion Rules")
                    .font(.headline)
                Text("Override how DexDictate inserts text for specific apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("How this works")
                        .font(.caption.bold())
                    Text("1. Set your global insertion behavior in Quick Settings first.")
                        .font(.caption)
                    Text("2. Bring the target app to the front and click \"Add Current App\" to capture it automatically, or use \"Add Manually\" if you already know the bundle ID.")
                        .font(.caption)
                    Text("3. Pick the insertion mode DexDictate should use only when that app is frontmost.")
                        .font(.caption)
                    Text("4. If you need to change a rule later, remove it and add it again with the new mode. This window is override-only, not inline-editable.")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Clipboard Paste uses the normal paste path. Accessibility API tries direct insertion at the cursor when the target app supports it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            HStack {
                Button("Add Current App") {
                    if let app = NSWorkspace.shared.frontmostApplication,
                       let bundleID = app.bundleIdentifier {
                        newBundleID = bundleID
                        newDisplayName = app.localizedName ?? bundleID
                        showAddRow = true
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Add Manually") {
                    newBundleID = ""
                    newDisplayName = ""
                    showAddRow = true
                }
                .buttonStyle(.borderless)
                .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if showAddRow {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Name")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("Display name", text: $newDisplayName)
                                .font(.caption)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bundle ID")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("com.example.App", text: $newBundleID)
                                .font(.caption)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mode")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $newMode) {
                                ForEach(InsertionModeOverride.allCases.filter { $0 != .useGlobal }) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }
                    }
                    HStack {
                        Button("Save") {
                            let bundleID = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                            let displayName = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !bundleID.isEmpty else { return }
                            manager.add(
                                AppInsertionOverride(
                                    bundleID: bundleID,
                                    displayName: displayName.isEmpty ? bundleID : displayName,
                                    mode: newMode
                                )
                            )
                            showAddRow = false
                            newBundleID = ""
                            newDisplayName = ""
                            newMode = .clipboardPaste
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Cancel") {
                            showAddRow = false
                            newBundleID = ""
                            newDisplayName = ""
                            newMode = .clipboardPaste
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()
            }

            if manager.overrides.isEmpty {
                Text("No per-app rules configured. All apps use the global insertion setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.overrides) { override in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(override.displayName)
                                        .font(.caption.bold())
                                    Text(override.bundleID)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 200, alignment: .leading)

                                Text(override.mode.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    manager.remove(id: override.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)

                            Divider().padding(.leading)
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(width: 540, height: 460)
    }
}
