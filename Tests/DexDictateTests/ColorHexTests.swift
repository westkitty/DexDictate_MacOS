import XCTest
import SwiftUI
@testable import DexDictateKit

final class ColorHexTests: XCTestCase {
    func testHexRoundTripIsStable() {
        let color = Color(hex: "#34C759")
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.hexString().uppercased(), "#34C759")
    }

    func testAcceptsHexWithoutHashAndLowercase() {
        XCTAssertEqual(Color(hex: "ff0000")?.hexString().uppercased(), "#FF0000")
        XCTAssertEqual(Color(hex: "#0000ff")?.hexString().uppercased(), "#0000FF")
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(Color(hex: "nope"))
        XCTAssertNil(Color(hex: "#12"))
        XCTAssertNil(Color(hex: ""))
        XCTAssertNil(Color(hex: "#1234567"))
    }
}
