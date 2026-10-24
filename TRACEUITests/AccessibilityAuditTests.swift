import XCTest

/// M8 step 3: the first-run screen and every tab pass Apple's accessibility audit
/// (labels, Dynamic Type clipping, contrast, hit regions). Run on the simulator.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true   // list every screen's issues in one run
    }

    func testFirstRunPassesAudit() throws {
        let app = XCUIApplication()
        app.launch()
        try audit(app, "first run")
    }

    func testEveryTabPassesAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES"]
        app.launch()
        for tab in ["TODAY", "RIDES", "MONEY", "BIKE"] {
            app.buttons[tab].tap()
            // The tab is selected at once but the 180 ms slide runs on; wait it out or the shot catches both screens.
            Thread.sleep(forTimeInterval: 0.6)
            try audit(app, tab)
        }
    }

    /// Typing the note brings up the system keyboard and hides the numeric keypad, so the two never stack.
    func testNoteHidesKeypad() {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES"]
        app.launch()
        app.buttons["MONEY"].tap()
        app.buttons["+ ADD EXPENSE"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "food")).firstMatch.tap()
        XCTAssertTrue(app.buttons["SAVE"].waitForExistence(timeout: 2), "keypad should show once a category is picked")
        app.textFields.firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2), "system keyboard should show for the note")
        XCTAssertTrue(app.buttons["SAVE"].waitForNonExistence(timeout: 2), "keypad should hide while typing a note")
    }

    /// Prints every issue before failing, so one run shows the whole list.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screen
        shot.lifetime = .keepAlways
        add(shot)
        try app.performAccessibilityAudit { issue in
            print("A11Y [\(screen)] \(issue.auditType) | \(issue.compactDescription) | \(issue.detailedDescription) | element: \(issue.element?.debugDescription ?? "none")")
            return false
        }
    }
}
