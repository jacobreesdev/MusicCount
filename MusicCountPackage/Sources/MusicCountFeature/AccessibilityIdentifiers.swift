import Foundation

/// Accessibility identifiers for UI testing.
enum AccessibilityIdentifiers {
    // MARK: - Library Tab

    enum Library {
        static let songList = "library.songList"
        static let sortButton = "library.sortButton"
        static let clearSelectionButton = "library.clearSelectionButton"
        static let floatingActionButton = "library.floatingActionButton"
        static let searchField = "library.searchField"

        static func songRow(id: UInt64) -> String {
            "library.songRow.\(id)"
        }
    }

    // MARK: - Comparison View

    enum Comparison {
        static let scrollView = "comparison.scrollView"
        static let song1Card = "comparison.song1Card"
        static let song2Card = "comparison.song2Card"
        static let matchModeButton = "comparison.matchModeButton"
        static let addModeButton = "comparison.addModeButton"
        static let tooltip = "comparison.tooltip"
        static let doneButton = "comparison.doneButton"
    }

    // MARK: - Suggestion Repair View

    enum SuggestionRepair {
        static let scrollView = "suggestionRepair.scrollView"
        static let buildRepairQueueButton = "suggestionRepair.buildRepairQueueButton"

        static func canonicalSongButton(id: UInt64) -> String {
            "suggestionRepair.canonicalSong.\(id)"
        }

        static func retiredSongToggle(id: UInt64) -> String {
            "suggestionRepair.retiredSong.\(id)"
        }
    }

    // MARK: - Manual Queue View

    enum ManualQueue {
        static let playsTextField = "manualQueue.playsTextField"
        static let decrementButton = "manualQueue.decrementButton"
        static let incrementButton = "manualQueue.incrementButton"
        static let addToQueueButton = "manualQueue.addToQueueButton"
        static let cancelButton = "manualQueue.cancelButton"

        static func quickAddButton(amount: Int) -> String {
            "manualQueue.quickAdd.\(amount)"
        }
    }

    // MARK: - Suggestions Tab

    enum Suggestions {
        static let suggestionsList = "suggestions.list"
        static let sortButton = "suggestions.sortButton"
        static let emptyState = "suggestions.emptyState"

        static func suggestionCard(title: String) -> String {
            "suggestions.card.\(title.replacingOccurrences(of: " ", with: "_"))"
        }
    }

    // MARK: - Settings

    enum Settings {
        static let queueBehaviorPicker = "settings.queueBehaviorPicker"
        static let resetDismissalsButton = "settings.resetDismissalsButton"
    }

    // MARK: - Tab Bar

    enum TabBar {
        static let libraryTab = "tabBar.library"
        static let suggestionsTab = "tabBar.suggestions"
        static let settingsTab = "tabBar.settings"
    }
}
