import AppKit
import Foundation

public enum HistoryTextVariant: Equatable, Sendable {
    case raw
    case cleaned

    public var label: String {
        switch self {
        case .raw: return "Raw"
        case .cleaned: return "Cleaned"
        }
    }
}

public struct HistoryDisplayContent: Equatable, Sendable {
    public let rawText: String
    public let cleanedText: String?

    public init(item: HistoryItem) {
        rawText = item.text
        cleanedText = item.cleanedText
    }

    public var hasDistinctCleanedText: Bool {
        guard let cleanedText else { return false }
        return cleanedText != rawText
    }

    public func effectiveVariant(preferred: HistoryTextVariant) -> HistoryTextVariant {
        preferred == .cleaned && hasDistinctCleanedText ? .cleaned : .raw
    }

    public func text(preferred: HistoryTextVariant) -> String {
        switch effectiveVariant(preferred: preferred) {
        case .raw:
            return rawText
        case .cleaned:
            return cleanedText ?? rawText
        }
    }
}

public enum TranscriptCopyResult: Equatable, Sendable {
    case copied
    case failed

    public var feedbackText: String {
        switch self {
        case .copied: return "Copied"
        case .failed: return "Copy failed"
        }
    }

    public var accessibilityAnnouncement: String {
        switch self {
        case .copied: return "Copied to clipboard."
        case .failed: return "Copy failed."
        }
    }
}

public enum TranscriptCopyAction {
    @discardableResult
    public static func copy(_ text: String) -> TranscriptCopyResult {
        copy(text) { value in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.setString(value, forType: .string)
        }
    }

    @discardableResult
    static func copy(
        _ text: String,
        using writer: (String) -> Bool
    ) -> TranscriptCopyResult {
        writer(text) ? .copied : .failed
    }

    public static func announce(_ result: TranscriptCopyResult) {
        let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
            .announcement: result.accessibilityAnnouncement,
            .priority: NSAccessibilityPriorityLevel.high.rawValue
        ]
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: userInfo
        )
    }
}

public enum HistoryPresentation {
    public static func shouldOfferExpansion(
        for text: String,
        collapsedCharacterLimit: Int = 180
    ) -> Bool {
        text.count > collapsedCharacterLimit || text.components(separatedBy: .newlines).count > 3
    }

    public static func relativeTimestamp(
        for date: Date,
        relativeTo referenceDate: Date = Date(),
        locale: Locale = .current
    ) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: referenceDate)
    }

    public static func exactTimestamp(
        for date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        return formatter.string(from: date)
    }

    public static func accessibilitySummary(
        item: HistoryItem,
        displayedText: String,
        variant: HistoryTextVariant,
        position: Int,
        total: Int
    ) -> String {
        let content = HistoryDisplayContent(item: item)
        var parts = [
            "Recent transcription \(position) of \(total).",
            displayedText,
            "Recorded \(exactTimestamp(for: item.createdAt))."
        ]
        if content.hasDistinctCleanedText {
            parts.append("\(variant.label) text.")
        }
        if item.isAccuracyRetry {
            parts.append("Quality retry.")
        }
        return parts.joined(separator: " ")
    }
}
