import XCTest

/// M7 exits on the simulator: last trip's cost from a cold open, a 200 km ride detail, the offline map.
/// Needs rides in the store; the Mac is faster than the phone, so these are a floor, not the phone result.
@MainActor
final class ReplayTimingTests: XCTestCase {
    private let backup = NSHomeDirectory().components(separatedBy: "/Library/Developer").first! + "/Library/Caches/trace-backup-2026-10-28"

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "km", "moving"))
    }

    /// Launch to the last trip's rupee amount on screen, in seconds (exit: under 10).
    func testColdOpenShowsLastTripCost() {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES", "-restoreFrom", backup, "-localStubOwnerID", "be6a1ffb-f72d-4433-8f2f-a9e2a04206c3"]
        let t0 = Date()
        app.launch()
        app.buttons["RIDES"].tap()
        let cost = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "₹")).firstMatch
        XCTAssertTrue(cost.waitForExistence(timeout: 10), "no rupee amount within 10 s")
        let s = Date().timeIntervalSince(t0)
        for r in rows(app).allElementsBoundByIndex.prefix(12) { print("ROW \(r.label)") }
        print("TIMING cold open to last trip cost: \(String(format: "%.2f", s)) s")
        XCTAssertLessThan(s, 10)
    }

    /// Tap the 200 km ride to its map and elevation being on screen (exit: under 2 s).
    func testLongRideOpensUnderTwoSeconds() {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES", "-seedLongRide", "-restoreFrom", backup, "-localStubOwnerID", "be6a1ffb-f72d-4433-8f2f-a9e2a04206c3"]
        app.launch()
        app.buttons["RIDES"].tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "TEST 200 KM")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        let t0 = Date()
        row.tap()
        let map = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Route map")).firstMatch
        let elevation = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Elevation from")).firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 10), "map did not appear")
        let mapS = Date().timeIntervalSince(t0)
        XCTAssertTrue(elevation.waitForExistence(timeout: 10), "elevation did not appear")
        let s = Date().timeIntervalSince(t0)
        print("TIMING 200 km ride: map \(String(format: "%.2f", mapS)) s, elevation \(String(format: "%.2f", s)) s")
        add(XCTAttachment(screenshot: app.screenshot()))
        XCTAssertLessThan(s, 2)
    }

    /// With the network forced off, a real ride shows the designed offline drawing.
    func testOfflineMapShowsDrawing() {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES", "-forceOffline", "-restoreFrom", backup, "-localStubOwnerID", "be6a1ffb-f72d-4433-8f2f-a9e2a04206c3"]
        app.launch()
        app.buttons["RIDES"].tap()
        let row = rows(app).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.staticTexts["OFFLINE MAP"].waitForExistence(timeout: 5), "offline map slug missing")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "offline map"; shot.lifetime = .keepAlways; add(shot)
    }
}
