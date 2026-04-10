import Foundation
import DexDictateKit
import Darwin

@MainActor
final class SilverTongueServiceManager: ObservableObject {
    static let shared = SilverTongueServiceManager(settings: AppSettings.shared)

    enum ServiceState: Equatable {
        case dormant
        case starting
        case ready
        case error(String)
    }

    @Published private(set) var state: ServiceState = .dormant

    let host = "127.0.0.1"
    let port: UInt16 = 49152
    let client: SilverTongueClient

    private let settings: AppSettings
    private var serviceProcess: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stderrBuffer = Data()
    private var expectedTermination = false
    private var manageVoicesProcess: Process?

    init(settings: AppSettings = .shared) {
        self.settings = settings
        self.client = SilverTongueClient(baseURL: URL(string: "http://127.0.0.1:49152")!)
    }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    func startIfNeeded() async {
        guard settings.silverTongueEnabled else {
            return
        }
        if case .ready = state { return }
        if case .starting = state { return }

        guard Self.isPortAvailable(port) else {
            state = .error("SilverTongue fixed port \(port) is already in use.")
            return
        }

        do {
            state = .starting
            try launchServiceProcess()
            let ready = await waitUntilHealthy(maxAttempts: 40, delayNanoseconds: 250_000_000)
            guard ready else {
                let suffix = latestServiceErrorSuffix()
                stopService()
                state = .error("SilverTongue service failed to become healthy on 127.0.0.1:\(port).\(suffix)")
                return
            }
            state = .ready
        } catch {
            stopService()
            state = .error(error.localizedDescription)
        }
    }

    func stopService() {
        guard let serviceProcess else {
            terminateStaleServiceOnFixedPort()
            state = .dormant
            return
        }

        expectedTermination = true
        serviceProcess.terminate()
        cleanupProcess(resetStderr: false)
        state = .dormant
    }

    func stopManageVoices() {
        guard let manageVoicesProcess else { return }
        if manageVoicesProcess.isRunning {
            manageVoicesProcess.terminate()
        }
        self.manageVoicesProcess = nil
    }

    func shutdown() {
        stopService()
        stopManageVoices()
    }

    func launchManageVoices() throws {
        if let manageVoicesProcess, manageVoicesProcess.isRunning {
            return
        }

        let installURL = try resolveInstallDirectory()
        let electronEntryURL = installURL.appendingPathComponent("dist/electron/main.js")

        // Prefer the native Electron binary directly (avoids needing node on PATH).
        // node_modules/.bin/electron is a shell script that calls `node`, which is
        // not on the minimal PATH that macOS GUI apps receive — so use the binary itself.
        let electronBinaryURL = installURL
            .appendingPathComponent("node_modules/electron/dist/Electron.app/Contents/MacOS/Electron")

        guard FileManager.default.isExecutableFile(atPath: electronBinaryURL.path) else {
            throw NSError(
                domain: "SilverTongueServiceManager",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey:
                    "Electron binary not found at \(electronBinaryURL.path). Run `pnpm install` in the SilverTongue repo."]
            )
        }

        guard FileManager.default.fileExists(atPath: electronEntryURL.path) else {
            throw NSError(
                domain: "SilverTongueServiceManager",
                code: 13,
                userInfo: [NSLocalizedDescriptionKey:
                    "SilverTongue Electron entrypoint is missing at \(electronEntryURL.path). Run `pnpm build` in the SilverTongue repo."]
            )
        }

        let process = Process()
        process.executableURL = electronBinaryURL
        process.arguments = [electronEntryURL.path, "--open-training"]
        process.currentDirectoryURL = installURL
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.manageVoicesProcess = nil
            }
        }
        try process.run()
        self.manageVoicesProcess = process
    }

    private func launchServiceProcess() throws {
        let (installURL, serviceEntryURL) = try resolveServiceEntrypoint()
        let nodeURL = try resolveNodeExecutable()

        cleanupProcess(resetStderr: true)
        expectedTermination = false

        let process = Process()
        process.executableURL = nodeURL
        process.currentDirectoryURL = installURL
        process.arguments = [serviceEntryURL.path, "service", "start", "--port", String(port)]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.stderrBuffer.append(data)
            }
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor [weak self] in
                self?.handleServiceTermination(terminatedProcess)
            }
        }

        do {
            try process.run()
        } catch {
            throw NSError(
                domain: "SilverTongueServiceManager",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey:
                    "Failed to launch SilverTongue service with node at \(nodeURL.path): \(error.localizedDescription)"]
            )
        }

        self.serviceProcess = process
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
    }

    private func handleServiceTermination(_ process: Process) {
        let expected = expectedTermination
        expectedTermination = false

        if expected {
            cleanupProcess(resetStderr: false)
            if case .error = state {
                return
            }
            state = .dormant
            return
        }

        let status = process.terminationStatus
        let suffix = latestServiceErrorSuffix()
        cleanupProcess(resetStderr: false)
        state = .error("SilverTongue service exited unexpectedly (code \(status)).\(suffix)")
    }

    private func waitUntilHealthy(maxAttempts: Int, delayNanoseconds: UInt64) async -> Bool {
        for _ in 0..<maxAttempts {
            if await client.health() {
                return true
            }
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return false
    }

    private func cleanupProcess(resetStderr: Bool) {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
        serviceProcess = nil
        if resetStderr {
            stderrBuffer.removeAll(keepingCapacity: true)
        }
    }

    private func latestServiceErrorSuffix() -> String {
        guard
            let stderr = String(data: stderrBuffer, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !stderr.isEmpty
        else {
            return ""
        }

        let singleLine = stderr
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
        return " \(singleLine)"
    }

    private func resolveServiceEntrypoint() throws -> (URL, URL) {
        let installURL = try resolveInstallDirectory()
        let serviceEntryURL = installURL.appendingPathComponent("dist/src/cli/index.js")

        guard FileManager.default.fileExists(atPath: serviceEntryURL.path) else {
            throw NSError(
                domain: "SilverTongueServiceManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey:
                    "SilverTongue CLI build output is missing at \(serviceEntryURL.path). Run `pnpm build` in the SilverTongue repo."]
            )
        }

        return (installURL, serviceEntryURL)
    }

    private func resolveInstallDirectory() throws -> URL {
        if let configured = configuredInstallURL() {
            guard isValidInstallDirectory(configured) else {
                throw NSError(
                    domain: "SilverTongueServiceManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Configured SilverTongue path is invalid: \(configured.path). It must contain package.json."]
                )
            }
            return configured
        }

        if let envConfigured = environmentInstallURL(),
           isValidInstallDirectory(envConfigured) {
            return envConfigured
        }

        for candidate in fallbackInstallURLs() where isValidInstallDirectory(candidate) {
            return candidate
        }

        throw NSError(
            domain: "SilverTongueServiceManager",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey:
                "Unable to locate SilverTongue installation. Set the path in DexDictate Quick Settings."]
        )
    }

    private func resolveNodeExecutable() throws -> URL {
        if let configuredNode = configuredNodeURL() {
            guard FileManager.default.isExecutableFile(atPath: configuredNode.path) else {
                throw NSError(
                    domain: "SilverTongueServiceManager",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Configured Node path is not executable: \(configuredNode.path)"]
                )
            }
            return configuredNode
        }

        let commonNodePaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ]
        for path in commonNodePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        if let discovered = resolveNodeViaPATH() {
            return discovered
        }

        throw NSError(
            domain: "SilverTongueServiceManager",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey:
                "Node.js runtime was not found. Install Node 20+ or set a Node path in Quick Settings."]
        )
    }

    private func resolveNodeViaPATH() -> URL? {
        resolveExecutableViaPATH("node")
    }

    private func resolveExecutableViaPATH(_ name: String) -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty,
            FileManager.default.isExecutableFile(atPath: path)
        else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func configuredInstallURL() -> URL? {
        let trimmed = settings.silverTongueInstallPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
    }

    private func environmentInstallURL() -> URL? {
        guard let raw = ProcessInfo.processInfo.environment["DEXDICTATE_SILVERTONGUE_PATH"],
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
    }

    private func configuredNodeURL() -> URL? {
        let raw = settings.silverTongueNodePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
        }

        if let envRaw = ProcessInfo.processInfo.environment["DEXDICTATE_NODE_PATH"],
           !envRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: (envRaw as NSString).expandingTildeInPath)
        }

        return nil
    }

    private func fallbackInstallURLs() -> [URL] {
        let fileManager = FileManager.default
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let candidates = [
            cwd.appendingPathComponent("../SilverTongue").standardizedFileURL,
            cwd.appendingPathComponent("SilverTongue").standardizedFileURL,
            home.appendingPathComponent("Projects/SilverTongue").standardizedFileURL
        ]

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }

    private func isValidInstallDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        let packageJSON = url.appendingPathComponent("package.json")
        return FileManager.default.fileExists(atPath: packageJSON.path)
    }

    private func terminateStaleServiceOnFixedPort() {
        let pids = pidsListening(on: Int(port))
        guard !pids.isEmpty else { return }

        for pid in pids {
            guard let command = processCommand(pid: pid) else { continue }
            let normalized = command.lowercased()
            guard
                normalized.contains("dist/src/cli/index.js"),
                normalized.contains("service"),
                normalized.contains("start"),
                normalized.contains("--port \(port)")
            else {
                continue
            }
            _ = Darwin.kill(pid_t(pid), SIGTERM)
        }
    }

    private func pidsListening(on port: Int) -> [Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return []
        }

        return text
            .split(separator: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func processCommand(pid: Int32) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", String(pid), "-o", "command="]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isPortAvailable(_ port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var one: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return bindResult == 0
    }
}
