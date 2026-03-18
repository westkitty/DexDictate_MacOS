import Foundation

public struct FlavorLine: Identifiable, Hashable, Codable {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var id: String { text }
}
