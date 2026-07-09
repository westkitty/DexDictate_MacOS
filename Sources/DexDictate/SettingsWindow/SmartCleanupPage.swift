import SwiftUI
import DexDictateKit

/// Settings → Smart Cleanup (Packet 13). LLM post-processing of the already-committed,
/// already-delivered transcript via an OpenAI-compatible endpoint (e.g. a tunneled remote
/// Ollama). This is NOT a transcription provider — it never appears in Models & Accuracy,
/// never changes when or what text is inserted, and defaults off. `SmartCleanupSettings`
/// and `SmartCleanupCoordinator` are new, isolated singletons (`Sources/DexDictateKit/SmartCleanup/`)
/// — zero edits to `TranscriptionEngine.swift` or any other forbidden file.
struct SmartCleanupPage: View {
    @ObservedObject private var settings = SmartCleanupSettings.shared
    @ObservedObject private var coordinator = SmartCleanupCoordinator.shared

    @State private var baseURLDraft: String = ""
    @State private var modelDraft: String = ""
    @State private var apiKeyDraft: String = ""
    @State private var isTunnelHelpExpanded = false

    @State private var isTestingConnection = false
    @State private var connectionResultText: String?
    @State private var isTestingInference = false
    @State private var inferenceResultText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SurfaceTokens.settingsSectionSpacing) {
                Text(SettingsPage.smartCleanup.title)
                    .font(.title2.bold())

                Toggle("Enable Smart Cleanup", isOn: $settings.enabled)

                Text("Provider")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("OpenAI-Compatible Server (Ollama, etc.)")
                    .font(.callout)

                Divider()

                connectionFields

                HStack(spacing: 10) {
                    Button {
                        Task { await runTestConnection() }
                    } label: {
                        HStack(spacing: 6) {
                            if isTestingConnection { ProgressView().controlSize(.small) }
                            Text("Test Connection")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingConnection || baseURLDraft.isEmpty)

                    Button {
                        Task { await runTestInference() }
                    } label: {
                        HStack(spacing: 6) {
                            if isTestingInference { ProgressView().controlSize(.small) }
                            Text("Test Inference")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingInference || baseURLDraft.isEmpty || modelDraft.isEmpty)
                }

                if let connectionResultText {
                    Text(connectionResultText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let inferenceResultText {
                    Text(inferenceResultText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if SmartCleanupURLValidation.isNonLoopbackCleartext(baseURLDraft) {
                    WarningCallout(text: "This address is not local. Without a tunnel, your text will travel unencrypted.")
                }

                Divider()

                tunnelHelp

                Divider()

                Text("If cleanup fails or times out, DexDictate delivers the raw transcript unchanged. Cleanup runs after delivery — it never delays or changes what gets inserted.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SurfaceTokens.settingsPagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            baseURLDraft = settings.baseURLString
            modelDraft = settings.model
            apiKeyDraft = settings.apiKey
        }
        .onChange(of: baseURLDraft) { _, newValue in settings.baseURLString = newValue }
        .onChange(of: modelDraft) { _, newValue in settings.model = newValue }
        .onChange(of: apiKeyDraft) { _, newValue in settings.apiKey = newValue }
    }

    private var connectionFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("http://127.0.0.1:11435/v1", text: $baseURLDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("llama3", text: $modelDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("ollama", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
            }
        }
    }

    private var tunnelHelp: some View {
        DisclosureGroup("How the tunnel works", isExpanded: $isTunnelHelpExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ssh -N -L <LOCAL_PORT>:127.0.0.1:11434 <USER>@<HOST>")
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("127.0.0.1 always means this Mac. If your model runs on another machine, you need a tunnel: then 127.0.0.1:<LOCAL_PORT> on this Mac forwards to the server. Port 11435 is a common local choice because it avoids clashing with a local Ollama on 11434 — but any unused port works; it is never hard-coded here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use SSH or Tailscale for the tunnel — never expose the remote server's port directly to the internet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
        .font(.caption.weight(.semibold))
    }

    private func runTestConnection() async {
        isTestingConnection = true
        connectionResultText = nil
        defer { isTestingConnection = false }

        let result = await SmartCleanupClient.testConnection(baseURLString: baseURLDraft, apiKey: apiKeyDraft)
        switch result {
        case .success(let models):
            connectionResultText = "Connected — \(models.modelIDs.count) model(s): \(models.modelIDs.prefix(5).joined(separator: ", "))"
        case .failure(let error):
            connectionResultText = "Connection failed: \(error.localizedDescription)"
        }
        await coordinator.refreshReachability()
    }

    private func runTestInference() async {
        isTestingInference = true
        inferenceResultText = nil
        defer { isTestingInference = false }

        let result = await SmartCleanupClient.testInference(baseURLString: baseURLDraft, model: modelDraft, apiKey: apiKeyDraft)
        switch result {
        case .success(let inference):
            inferenceResultText = "Reply: \"\(inference.reply)\" — \(inference.roundTripMS) ms"
        case .failure(let error):
            inferenceResultText = "Inference failed: \(error.localizedDescription)"
        }
    }
}
