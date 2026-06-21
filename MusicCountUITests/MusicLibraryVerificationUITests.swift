import XCTest

final class MusicLibraryVerificationUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testMockDataLaunchShowsLibraryAndSuggestions() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-ResetRepairState"])
        app.launch()

        XCTAssertFalse(app.staticTexts["Access Denied"].exists)
        XCTAssertTrue(app.staticTexts["Blinding Lights"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.searchFields["Search songs"].exists)

        app.tabBars.buttons["Suggestions"].tap()

        XCTAssertTrue(app.searchFields["Search suggestions"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Blinding Lights"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMockActiveRepairCanBeMarkedDone() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-MockActiveRepairs"])
        app.launch()

        app.tabBars.buttons["Suggestions"].tap()
        XCTAssertTrue(app.searchFields["Search suggestions"].waitForExistence(timeout: 10))

        let completedRepairDoneButton = app.buttons["suggestions.activeRepair.done.blinding lights-the weeknd"]
        XCTAssertTrue(completedRepairDoneButton.waitForExistence(timeout: 10))

        completedRepairDoneButton.tap()

        let completionAlert = app.alerts["Repair Marked Done"]
        XCTAssertTrue(completionAlert.waitForExistence(timeout: 10))

        let playlistWarning = completionAlert.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "could not update the Songs to Remove Playlist")
        ).firstMatch
        XCTAssertTrue(playlistWarning.exists)

        completionAlert.buttons["OK"].tap()

        XCTAssertFalse(completedRepairDoneButton.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["suggestions.activeRepair.done.shake it off-taylor swift"].waitForExistence(timeout: 5))
    }
}
