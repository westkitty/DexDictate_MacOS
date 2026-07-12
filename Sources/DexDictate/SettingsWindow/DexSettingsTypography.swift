import SwiftUI

/// Shared Settings typography, tuned to match `HelpView`'s existing hierarchy — opacity-graded
/// white text (`.foregroundStyle(.white.opacity(...))`) — rather than SwiftUI's semantic
/// `.secondary`, which several Settings pages used instead and which reads visibly flatter/
/// grayer than Help by direct comparison. Using these instead of ad hoc `.font`/
/// `.foregroundStyle` pairs keeps pages from drifting independently and lets future pages
/// inherit the same hierarchy automatically.
///
/// Hierarchy (strongest → weakest): `DexPageTitle` > `DexSectionTitle` > control labels
/// (untouched, still whatever SwiftUI/`SettingToggleWithInfo` already renders) >
/// `DexSectionDescription` > `DexSecondaryText`. None of these change layout, spacing, control
/// behavior, or the Dexter watermark — they only standardize font/opacity on existing text.

/// Page-level title (e.g. "General", "Dictation") — matches `HelpContentView`'s per-section
/// header (`.title2.bold()`, full-opacity white).
struct DexPageTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(.white)
    }
}

/// Section header within a page (e.g. "Interface", "During Dictation") — matches Help's
/// `helpHeading` (`.callout.weight(.semibold)`, full-opacity white).
struct DexSectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
    }
}

/// Explanatory/supporting copy below a control or section header — matches Help's
/// `helpBody` (`.callout`, white at 88% opacity), the step Settings pages most often
/// under-emphasized by using `.caption` + semantic `.secondary` instead.
struct DexSectionDescription: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Tertiary/metadata text (fine print, status captions) — matches Help's caption-level
/// treatment at a lower opacity than `DexSectionDescription`, still legible, never below
/// reasonable contrast.
struct DexSecondaryText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.5))
    }
}
