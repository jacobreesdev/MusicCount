import XCTest

final class MusicLibraryVerificationUITests: XCTestCase {
    private let mockLibraryAnchorTitle = "hate that i made you love me"
    private let longLibrarySongTitle = "hate that i made you love me (ari lyric draft from bed)"
    private let suggestionSearchQuery = "begged"

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
        waitForMockSuggestionsToLoad(in: app)

        app.tabBars.buttons["Library"].tap()
        waitForMockLibraryToLoad(in: app)
        XCTAssertTrue(app.searchFields["Search songs"].exists)
        app.tabBars.buttons["Suggestions"].tap()

        let searchField = app.searchFields["Search suggestions"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText(suggestionSearchQuery)

        XCTAssertTrue(app.staticTexts["begged"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["begged (Saturday Night Live 2026)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 versions"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSuggestionsFirstLaunchKeepsLibraryAvailableForManualQueueing() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-ResetRepairState"])
        app.launch()

        waitForMockSuggestionsToLoad(in: app)

        app.tabBars.buttons["Library"].tap()
        waitForMockLibraryToLoad(in: app)

        let searchField = app.searchFields["Search songs"]
        XCTAssertTrue(searchField.exists)
        searchField.tap()
        searchField.typeText(mockLibraryAnchorTitle)
        dismissKeyboard(in: app)

        let song = app.staticTexts[mockLibraryAnchorTitle].firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        song.swipeLeft()
        XCTAssertTrue(app.buttons["Select for Manual Queue"].waitForExistence(timeout: 5))
        app.buttons["Select for Manual Queue"].tap()

        let manualQueueButton = app.buttons["library.floatingActionButton"]
        XCTAssertTrue(manualQueueButton.waitForExistence(timeout: 5))
        XCTAssertEqual(manualQueueButton.label, "Manual Queue")
        manualQueueButton.tap()

        XCTAssertTrue(app.staticTexts["Manual Queue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Manual Plays"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Manual Plays"].exists)
        XCTAssertFalse(
            app.staticTexts["Comparison"].exists,
            "The secondary Library Song browser should not route selected songs through the old comparison repair path."
        )
    }

    @MainActor
    func testLibraryNoResultsSearchKeepsSearchFieldReachable() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-ResetRepairState"])
        app.launch()

        app.tabBars.buttons["Library"].tap()
        waitForMockLibraryToLoad(in: app)

        let searchField = app.searchFields["Search songs"]
        XCTAssertTrue(searchField.exists)

        let noMatchQuery = "zzzz-no-results"
        searchField.tap()
        searchField.typeText(noMatchQuery)

        XCTAssertTrue(
            app.searchFields["Search songs"].waitForExistence(timeout: 2),
            "The Library search field should remain reachable when there are no matching Library Songs."
        )
        XCTAssertTrue(app.staticTexts["No Matching Songs"].waitForExistence(timeout: 2))

        clearSearchField(app.searchFields["Search songs"], in: app, deleting: noMatchQuery)

        let recoveredSearchField = app.searchFields["Search songs"]
        recoveredSearchField.tap()
        recoveredSearchField.typeText(mockLibraryAnchorTitle)

        XCTAssertTrue(app.staticTexts[mockLibraryAnchorTitle].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSuggestionsNoResultsSearchKeepsSearchFieldReachable() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-ResetRepairState"])
        app.launch()

        waitForMockSuggestionsToLoad(in: app)
        XCTAssertTrue(app.searchFields["Search suggestions"].waitForExistence(timeout: 10))

        let searchField = app.searchFields["Search suggestions"]
        let noMatchQuery = "zzzz-no-results"
        searchField.tap()
        searchField.typeText(noMatchQuery)

        XCTAssertTrue(
            app.searchFields["Search suggestions"].waitForExistence(timeout: 2),
            "The Suggestions search field should remain reachable when there are no matching Suggestions."
        )
        XCTAssertTrue(app.staticTexts["No Matching Suggestions"].waitForExistence(timeout: 2))

        clearSearchField(app.searchFields["Search suggestions"], in: app, deleting: noMatchQuery)

        searchField.tap()
        searchField.typeText(suggestionSearchQuery)
        XCTAssertTrue(app.staticTexts["begged"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLongLibrarySongTextWrapsInSuggestionsAndLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-ResetRepairState"])
        app.launch()

        waitForMockSuggestionsToLoad(in: app)

        let suggestionsSearchField = app.searchFields["Search suggestions"]
        suggestionsSearchField.tap()
        suggestionsSearchField.typeText(mockLibraryAnchorTitle)

        let suggestionTitle = app.staticTexts[longLibrarySongTitle].firstMatch
        XCTAssertTrue(suggestionTitle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(
            suggestionTitle.frame.height,
            singleLineTitleHeight,
            "Long Library Song text should wrap in Suggestions instead of staying on one line."
        )

        app.terminate()
        app.launch()

        app.tabBars.buttons["Library"].tap()
        waitForMockLibraryToLoad(in: app)

        let librarySearchField = app.searchFields["Search songs"]
        librarySearchField.tap()
        librarySearchField.typeText(longLibrarySongTitle)

        let libraryTitle = app.staticTexts[longLibrarySongTitle].firstMatch
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(
            libraryTitle.frame.height,
            singleLineTitleHeight,
            "Long Library Song text should wrap in Library instead of staying on one line."
        )
    }

    @MainActor
    func testMockActiveRepairCanBeMarkedDone() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-MockActiveRepairs"])
        app.launch()

        waitForMockSuggestionsToLoad(in: app)

        let completedRepairDoneButton = app.buttons["suggestions.activeRepair.done.blinding lights-the weeknd"]
        XCTAssertTrue(completedRepairDoneButton.waitForExistence(timeout: 10))

        let completionAlert = completeActiveRepair(using: completedRepairDoneButton, in: app)

        let playlistWarning = completionAlert.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "could not update the Songs to Remove Playlist")
        ).firstMatch
        XCTAssertTrue(playlistWarning.exists)

        completionAlert.buttons["OK"].tap()

        XCTAssertFalse(completedRepairDoneButton.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["suggestions.activeRepair.done.shake it off-taylor swift"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPlaylistSyncFailureCanBeRetriedFromActiveRepairs() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-MockData", "-MockActiveRepairs"])
        app.launch()

        waitForMockSuggestionsToLoad(in: app)

        let completedRepairDoneButton = app.buttons["suggestions.activeRepair.done.blinding lights-the weeknd"]
        XCTAssertTrue(completedRepairDoneButton.waitForExistence(timeout: 10))
        let completionAlert = completeActiveRepair(using: completedRepairDoneButton, in: app)
        completionAlert.buttons["OK"].tap()

        XCTAssertTrue(app.staticTexts["Songs to Remove Playlist May Be Stale"].waitForExistence(timeout: 5))

        let retryButton = app.buttons["Retry Playlist Sync"]
        XCTAssertTrue(retryButton.exists)

        retryButton.tap()

        let retryAlert = app.alerts["Playlist Sync Failed"]
        XCTAssertTrue(retryAlert.waitForExistence(timeout: 10))
        retryAlert.buttons["OK"].tap()

        XCTAssertTrue(app.staticTexts["Songs to Remove Playlist May Be Stale"].exists)
    }

    private func clearSearchField(_ searchField: XCUIElement, in app: XCUIApplication, deleting query: String) {
        let clearTextButton = app.buttons["Clear text"].firstMatch
        if clearTextButton.waitForExistence(timeout: 2) {
            clearTextButton.tap()
        } else {
            searchField.tap()
            for _ in query {
                searchField.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let searchButton = app.keyboards.buttons["Search"].firstMatch
        if searchButton.waitForExistence(timeout: 2) {
            searchButton.tap()
        }
    }

    private func completeActiveRepair(
        using doneButton: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let completionAlert = app.alerts["Repair Marked Done"]

        for attempt in 1...3 {
            doneButton.tap()

            if completionAlert.waitForExistence(timeout: 15) {
                return completionAlert
            }

            guard attempt < 3, doneButton.waitForExistence(timeout: 2) else { break }
        }

        XCTFail("Repair Marked Done alert did not appear after tapping the Active Repair done button.", file: file, line: line)
        return completionAlert
    }

    private func waitForMockLibraryToLoad(in app: XCUIApplication) {
        XCTAssertTrue(
            app.searchFields["Search songs"].waitForExistence(timeout: 20),
            "The full Library.xml mock data should load before Library interactions run."
        )
    }

    private func waitForMockSuggestionsToLoad(in app: XCUIApplication) {
        XCTAssertTrue(
            app.searchFields["Search suggestions"].waitForExistence(timeout: 20),
            "MusicCount should launch into Suggestions as the primary repair surface."
        )
    }

    private var singleLineTitleHeight: CGFloat {
        28
    }
}
