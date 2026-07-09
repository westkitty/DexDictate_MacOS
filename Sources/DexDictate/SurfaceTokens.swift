import SwiftUI

enum SurfaceTokens {
    static let sectionSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 10
    static let capsuleHorizontal: CGFloat = 10
    static let capsuleVertical: CGFloat = 5

    // MARK: - Settings window (Packet 15)
    // Formalizes the values every Settings page already used consistently since
    // Packets 02–12A — no visual change, just naming what was already coincidentally
    // uniform so it can't drift silently in future pages.
    static let settingsPagePadding: CGFloat = 24
    static let settingsSectionSpacing: CGFloat = 16
}
