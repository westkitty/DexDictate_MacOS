import Foundation

public enum AppProfile: String, CaseIterable, Codable, Identifiable {
    case standard
    case canadian
    case aussie

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .canadian:
            return "Canadian"
        case .aussie:
            return "Aussie"
        }
    }
}
