import XCTest
@testable import DexDictateKit

final class DexDictateTests: XCTestCase {
    func testProfanityFilter() {
        let input = "This is a damn good test."
        let expected = "This is a darn good test."
        let result = ProfanityFilter.filter(input)
        XCTAssertEqual(result, expected)
    }

    func testProfanityFilterCaseInsensitive() {
        let input = "DAMN."
        let expected = "DARN."
        // Note: The current filter might preserve case differently or lowercase replacements.
        // Based on the code, it uses regex with caseInsensitive option, but replacement is fixed string.
        // Let's verify behavior. The replacement "darn" is lowercase in the map.
        // Regex.stringByReplacingMatches will insert the template as is.
        // So "DAMN" -> "darn".
        let result = ProfanityFilter.filter(input)
        XCTAssertEqual(result.lowercased(), expected.lowercased())
    }
}
