import XCTest
@testable import DexDictateKit

final class DiagnosticsStoreTests: XCTestCase {
    func testDiagnosticsStoreRetainsOnlyNewestRecords() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let store = DiagnosticsStore(directoryURL: directoryURL, maxRecords: 3)
        store.append(DiagnosticRecord(timestamp: Date(), category: .general, message: "one"))
        store.append(DiagnosticRecord(timestamp: Date(), category: .general, message: "two"))
        store.append(DiagnosticRecord(timestamp: Date(), category: .general, message: "three"))
        store.append(DiagnosticRecord(timestamp: Date(), category: .general, message: "four"))

        let contents = try String(contentsOf: store.logURL, encoding: .utf8)
        let lines = contents.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertFalse(lines.joined(separator: "\n").contains("\"message\":\"one\""))
        XCTAssertTrue(lines.joined(separator: "\n").contains("\"message\":\"four\""))
    }
}
