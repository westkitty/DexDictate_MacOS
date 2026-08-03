import Foundation

/// Which popover body `DexDictateApp` mounts for a given set of persisted settings.
///
/// Exists because "which interface is the user actually looking at" was repeatedly inferred
/// from an `@AppStorage` default and repeatedly inferred wrong. Resolution is a pure function
/// of the stored values so it can be asserted in tests instead of assumed.
public enum PopoverRoute: String, Equatable, Sendable, CaseIterable {
    /// `PopoverRootView` — the shipped default.
    case slim
    /// `AntiGravityMainView` — reachable by turning `useSlimPopover` off.
    case classic

    public static func resolve(useSlimPopover: Bool) -> PopoverRoute {
        useSlimPopover ? .slim : .classic
    }

    /// Exactly one undo control is mounted per route, and this says where.
    public var undoControlPlacement: UndoControlPlacement {
        switch self {
        case .slim: return .besideAutoPaste
        case .classic: return .pinnedFooter
        }
    }
}

/// Where the single Undo Last Dictation control sits within a route.
///
/// It began in the latest-result card (invisible without a history item), moved to a footer
/// pinned at the very bottom (always mounted but reading as detached footer chrome), and now
/// sits beside the Auto-paste chip in the slim popover — next to the other delivery controls,
/// which is where it was asked for and where users look for it.
public enum UndoControlPlacement: String, Equatable, Sendable {
    /// Slim route: in the quick-action row, immediately right of the output chips.
    case besideAutoPaste
    /// Classic route: pinned above the route footer. That route has no Auto-paste chip row to
    /// sit beside, so the pinned placement is retained there rather than duplicated.
    case pinnedFooter
}

/// Full-content screen swaps *within* a route. Each of these replaces the normal result and
/// control surface wholesale, which is exactly how a control mounted inside that surface
/// disappears without any conditional appearing to be at fault.
public enum PopoverScreen: String, Equatable, Sendable, CaseIterable {
    /// The normal result-and-controls surface. Both routes have one.
    case main
    /// Slim route, ⌘K or the overflow menu.
    case commandPalette
    /// Classic route, Quick Settings expanded.
    case quickSettings

    /// Which routes can actually show this screen. `.main` belongs to both.
    public var reachableRoutes: [PopoverRoute] {
        switch self {
        case .main: return [.slim, .classic]
        case .commandPalette: return [.slim]
        case .quickSettings: return [.classic]
        }
    }
}

/// The chrome contract every popover route must satisfy.
///
/// `includesSharedUndoSurface` is a stored `true` rather than a computed condition on purpose.
/// Undo Last Dictation is route-level chrome, mounted beside the footer and outside every
/// screen swap, scroll container, and result-feedback branch — so there is no state, and no
/// combination of settings, under which it can be composed away. The control's *enablement*
/// still comes from `engine.undoAvailability`; only its presence is unconditional.
public struct PopoverChromeComposition: Equatable, Sendable {
    public let route: PopoverRoute
    public let screen: PopoverScreen
    public let includesSharedUndoSurface: Bool
    public let undoControlPlacement: UndoControlPlacement

    public init(route: PopoverRoute, screen: PopoverScreen) {
        self.route = route
        self.screen = screen
        self.includesSharedUndoSurface = true
        self.undoControlPlacement = route.undoControlPlacement
    }

    /// Every reachable (route, screen) pairing — the full set a test must hold the undo
    /// surface invariant across.
    public static var allReachable: [PopoverChromeComposition] {
        PopoverScreen.allCases.flatMap { screen in
            screen.reachableRoutes.map { PopoverChromeComposition(route: $0, screen: screen) }
        }
    }
}

/// One line describing what the popover actually mounted, emitted when it appears.
///
/// Deliberately carries no transcript, field, clipboard, or history text — only the resolved
/// route, the settings that chose it, the engine instance identity (so two engines can be told
/// apart), and the undo state with its reason.
public struct PopoverRouteDiagnostic {
    public let route: PopoverRoute
    public let screen: PopoverScreen
    public let useSlimPopover: Bool
    public let useExperimentalStateFirstUI: Bool
    public let useExperimentalCommandPalette: Bool
    public let engineIdentity: String
    public let undoAvailability: DictationUndoAvailability

    public init(
        route: PopoverRoute,
        screen: PopoverScreen,
        useSlimPopover: Bool,
        useExperimentalStateFirstUI: Bool,
        useExperimentalCommandPalette: Bool,
        engineIdentity: String,
        undoAvailability: DictationUndoAvailability
    ) {
        self.route = route
        self.screen = screen
        self.useSlimPopover = useSlimPopover
        self.useExperimentalStateFirstUI = useExperimentalStateFirstUI
        self.useExperimentalCommandPalette = useExperimentalCommandPalette
        self.engineIdentity = engineIdentity
        self.undoAvailability = undoAvailability
    }

    public var summary: String {
        let composition = PopoverChromeComposition(route: route, screen: screen)
        let undo = undoAvailability.canUndo
            ? "available"
            : "unavailable(\(undoAvailability.unavailableReason.map(Self.reasonTag) ?? "unknown"))"
        return """
        popover route=\(route.rawValue) screen=\(screen.rawValue) \
        undoSurfaceMounted=\(composition.includesSharedUndoSurface) \
        useSlimPopover=\(useSlimPopover) useExperimentalStateFirstUI=\(useExperimentalStateFirstUI) \
        useExperimentalCommandPalette=\(useExperimentalCommandPalette) \
        engine=\(engineIdentity) undo=\(undo)
        """
    }

    /// A stable short tag per case — the full `message` is user-facing prose and would make
    /// the log line unwieldy without adding diagnostic value.
    static func reasonTag(_ reason: DictationUndoUnavailableReason) -> String {
        switch reason {
        case .noDictationYet: return "noDictationYet"
        case .deliveryNotReversible: return "deliveryNotReversible"
        case .consumedBySuccessfulUndo: return "consumedBySuccessfulUndo"
        case .invalidatedByContentChange: return "invalidatedByContentChange"
        case .targetNoLongerExists: return "targetNoLongerExists"
        case .supersededByNewerDictation: return "supersededByNewerDictation"
        case .engineStopped: return "engineStopped"
        case .verificationPending: return "verificationPending"
        }
    }
}
