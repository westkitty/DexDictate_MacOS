import XCTest
@testable import DexDictateKit

/// The undo control was absent from the live popover across several repairs because each one
/// reasoned about the wrong surface: the control was mounted inside the latest-result card,
/// which renders nothing without a latest history item and which scrolls out of view when it
/// does render. These tests pin the two things source review kept getting wrong — which route
/// the persisted settings actually select, and whether the undo surface can be composed away.
///
/// They assert composition, not rendering. Rendering is verified live against the installed
/// build; see the route log emitted on popover appearance.
final class PopoverRouteCompositionTests: XCTestCase {

    // MARK: - Route resolution

    func testSlimPopoverSettingSelectsTheSlimRoute() {
        XCTAssertEqual(PopoverRoute.resolve(useSlimPopover: true), .slim)
    }

    func testDisablingSlimPopoverSelectsTheClassicRoute() {
        XCTAssertEqual(PopoverRoute.resolve(useSlimPopover: false), .classic)
    }

    // MARK: - The undo surface cannot be composed away

    func testEveryReachableRouteAndScreenIncludesTheSharedUndoSurface() {
        let reachable = PopoverChromeComposition.allReachable
        XCTAssertFalse(reachable.isEmpty)
        for composition in reachable {
            XCTAssertTrue(
                composition.includesSharedUndoSurface,
                "Route \(composition.route.rawValue)/\(composition.screen.rawValue) must mount the shared undo surface"
            )
        }
    }

    func testSlimRouteMainScreenIncludesTheSharedUndoSurface() {
        XCTAssertTrue(PopoverChromeComposition(route: .slim, screen: .main).includesSharedUndoSurface)
    }

    func testClassicRouteMainScreenIncludesTheSharedUndoSurface() {
        XCTAssertTrue(PopoverChromeComposition(route: .classic, screen: .main).includesSharedUndoSurface)
    }

    func testCommandPaletteReplacementDoesNotRemoveTheSharedUndoSurface() {
        XCTAssertTrue(PopoverChromeComposition(route: .slim, screen: .commandPalette).includesSharedUndoSurface)
    }

    func testQuickSettingsReplacementDoesNotRemoveTheSharedUndoSurface() {
        XCTAssertTrue(PopoverChromeComposition(route: .classic, screen: .quickSettings).includesSharedUndoSurface)
    }

    func testEveryScreenIsReachableFromAtLeastOneRoute() {
        for screen in PopoverScreen.allCases {
            XCTAssertFalse(screen.reachableRoutes.isEmpty, "\(screen.rawValue) is unreachable")
        }
        XCTAssertEqual(PopoverScreen.main.reachableRoutes.count, 2, "Both routes have a main screen")
    }

    // MARK: - Undo placement

    func testSlimRouteMountsUndoBesideAutoPaste() {
        for screen in PopoverScreen.main.reachableRoutes.contains(.slim) ? [PopoverScreen.main, .commandPalette] : [] {
            let composition = PopoverChromeComposition(route: .slim, screen: screen)
            XCTAssertEqual(
                composition.undoControlPlacement, .besideAutoPaste,
                "The active slim popover must place undo next to Auto-paste, not in a bottom footer"
            )
        }
    }

    func testSlimRouteNoLongerUsesTheBottomPinnedFooter() {
        XCTAssertNotEqual(PopoverChromeComposition(route: .slim, screen: .main).undoControlPlacement, .pinnedFooter)
    }

    func testClassicRouteKeepsItsPinnedFooterPlacement() {
        XCTAssertEqual(
            PopoverChromeComposition(route: .classic, screen: .main).undoControlPlacement, .pinnedFooter,
            "The classic route has no Auto-paste chip row to sit beside"
        )
    }

    func testEachRouteDeclaresExactlyOneUndoPlacement() {
        for composition in PopoverChromeComposition.allReachable {
            XCTAssertTrue(composition.includesSharedUndoSurface)
            XCTAssertEqual(
                composition.undoControlPlacement, composition.route.undoControlPlacement,
                "A route must not mount undo in two places"
            )
        }
    }

    /// The active slim popover mounts `PopoverQuickActionRow`; the pinned `PopoverUndoFooter`
    /// must not also appear there, or two undo buttons would be on screen at once.
    func testActiveSlimPopoverSourceMountsExactlyOneUndoSurface() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/DexDictate")
        let slim = try String(contentsOf: sources.appendingPathComponent("PopoverRootView.swift"), encoding: .utf8)

        XCTAssertTrue(slim.contains("PopoverQuickActionRow(engine:"), "Slim route must mount the quick-action row")
        XCTAssertFalse(slim.contains("PopoverUndoFooter("), "The bottom undo footer must be gone from the slim route")

        let classic = try String(contentsOf: sources.appendingPathComponent("DexDictateApp.swift"), encoding: .utf8)
        XCTAssertTrue(classic.contains("PopoverUndoFooter("), "The classic route keeps its pinned footer")
        XCTAssertFalse(classic.contains("PopoverQuickActionRow("), "Only one undo surface per route")
    }

    // MARK: - Presence is independent of undo availability

    /// The control is structural; only its enablement varies. Every unavailable reason — the
    /// no-history and idle-feedback states included — must still describe a mounted control.
    func testControlStaysMountedAndExplainsItselfForEveryUnavailableReason() {
        let reasons: [DictationUndoUnavailableReason] = [
            .noDictationYet,
            .deliveryNotReversible("it was delivered by clipboard paste"),
            .consumedBySuccessfulUndo,
            .invalidatedByContentChange,
            .targetNoLongerExists,
            .supersededByNewerDictation,
            .engineStopped
        ]

        for reason in reasons {
            let model = UndoControlModel(availability: .unavailable(reason))
            XCTAssertTrue(model.isVisible, "\(reason) must not hide the control")
            XCTAssertFalse(model.isEnabled)
            XCTAssertEqual(model.unavailableReason, reason)
            XCTAssertEqual(model.helpText, reason.message, "Disabled state must state the real reason")
            XCTAssertEqual(model.accessibilityHint, reason.message)
            XCTAssertFalse(model.accessibilityLabel.isEmpty)
        }
    }

    func testNoDictationYetStillExposesAnEnabledlessControlBeforeAnyHistoryExists() {
        let model = UndoControlModel(availability: .unavailable(.noDictationYet))
        XCTAssertTrue(model.isVisible)
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(model.title, "Undo Last Dictation")
    }

    func testEnabledAndDisabledStatesUseTheSameControlTitle() {
        let enabled = UndoControlModel(availability: .available)
        let disabled = UndoControlModel(availability: .unavailable(.noDictationYet))
        XCTAssertEqual(enabled.title, disabled.title, "One mounted control, two states — not two controls")
        XCTAssertTrue(enabled.isEnabled)
        XCTAssertTrue(enabled.isVisible)
        XCTAssertNil(enabled.unavailableReason)
    }

    func testUnverifiedDeliveryLeavesTheControlMountedWithItsReason() {
        let detail = OutputDelivery.requestedButUnverified.undoIneligibilityDetail
        let model = UndoControlModel(availability: .unavailable(.deliveryNotReversible(detail)))
        XCTAssertTrue(model.isVisible)
        XCTAssertFalse(model.isEnabled)
        XCTAssertTrue(model.helpText.contains("could not be confirmed"))
        // The on-screen line has to carry the reason too — the hover-only tooltip was
        // undiscoverable and the control read as inert footer text.
        XCTAssertEqual(model.statusLine, "Unavailable — this result used an unverified paste.")
    }

    // MARK: - Route diagnostic

    func testRouteDiagnosticReportsResolvedRouteSettingsAndUndoState() {
        let summary = PopoverRouteDiagnostic(
            route: .slim,
            screen: .main,
            useSlimPopover: true,
            useExperimentalStateFirstUI: true,
            useExperimentalCommandPalette: true,
            engineIdentity: "abc123",
            undoAvailability: .unavailable(.noDictationYet)
        ).summary

        XCTAssertTrue(summary.contains("route=slim"))
        XCTAssertTrue(summary.contains("screen=main"))
        XCTAssertTrue(summary.contains("undoSurfaceMounted=true"))
        XCTAssertTrue(summary.contains("useSlimPopover=true"))
        XCTAssertTrue(summary.contains("useExperimentalStateFirstUI=true"))
        XCTAssertTrue(summary.contains("engine=abc123"))
        XCTAssertTrue(summary.contains("undo=unavailable(noDictationYet)"))
    }

    func testRouteDiagnosticReportsAvailableUndo() {
        let summary = PopoverRouteDiagnostic(
            route: .classic,
            screen: .quickSettings,
            useSlimPopover: false,
            useExperimentalStateFirstUI: false,
            useExperimentalCommandPalette: false,
            engineIdentity: "deadbeef",
            undoAvailability: .available
        ).summary

        XCTAssertTrue(summary.contains("route=classic"))
        XCTAssertTrue(summary.contains("screen=quickSettings"))
        XCTAssertTrue(summary.contains("undo=available"))
    }
}
