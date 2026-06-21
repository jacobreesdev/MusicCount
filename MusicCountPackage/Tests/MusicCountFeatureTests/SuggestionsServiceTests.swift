import Foundation
import Testing
@testable import MusicCountFeature

/// Tests for SuggestionsService business logic.
@Suite("SuggestionsService Tests")
@MainActor
struct SuggestionsServiceTests {

    // MARK: - Test Fixtures

    /// Creates a fresh SuggestionsService with all dismissals cleared.
    private func makeFreshService() -> SuggestionsService {
        // Clear any persisted dismissals from previous test runs
        UserDefaults.standard.removeObject(forKey: StorageKeys.dismissedSuggestions)
        UserDefaults.standard.removeObject(forKey: StorageKeys.activeRepairs)
        return SuggestionsService()
    }

    private func makeSong(
        id: UInt64,
        title: String,
        artist: String,
        playCount: Int
    ) -> SongInfo {
        SongInfo(
            id: id,
            title: title,
            artist: artist,
            album: "Test Album",
            playCount: playCount,
            hasAssetURL: true,
            mediaType: "Music",
            duration: 200
        )
    }

    // MARK: - Analyze Songs Tests

    @Test("Groups songs by normalized title and artist")
    func analyzeSongsGrouping() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "hello", artist: "ADELE", playCount: 50), // Same, different case
            makeSong(id: 3, title: "Rolling in the Deep", artist: "Adele", playCount: 75),
        ]

        service.analyzeSongs(songs)

        #expect(service.allSuggestions.count == 1) // Only "Hello" has duplicates
        #expect(service.allSuggestions[0].songs.count == 2)
    }

    @Test("Creates no suggestions for unique songs")
    func analyzeSongsNoSuggestions() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Song A", artist: "Artist A", playCount: 100),
            makeSong(id: 2, title: "Song B", artist: "Artist B", playCount: 50),
            makeSong(id: 3, title: "Song C", artist: "Artist C", playCount: 75),
        ]

        service.analyzeSongs(songs)

        #expect(service.allSuggestions.isEmpty)
    }

    @Test("Creates multiple suggestion groups")
    func analyzeSongsMultipleGroups() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "Hello", artist: "Adele", playCount: 50),
            makeSong(id: 3, title: "Yellow", artist: "Coldplay", playCount: 75),
            makeSong(id: 4, title: "Yellow", artist: "Coldplay", playCount: 25),
        ]

        service.analyzeSongs(songs)

        #expect(service.allSuggestions.count == 2)
    }

    @Test("Handles empty song list")
    func analyzeSongsEmpty() {
        let service = makeFreshService()
        service.analyzeSongs([])
        #expect(service.allSuggestions.isEmpty)
    }

    @Test("Normalizes whitespace in titles")
    func analyzeSongsWhitespace() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello ", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: " Hello", artist: "Adele", playCount: 50),
        ]

        service.analyzeSongs(songs)

        #expect(service.allSuggestions.count == 1)
    }

    @Test("Different artists are separate groups")
    func analyzeSongsDifferentArtists() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "Hello", artist: "Lionel Richie", playCount: 50),
        ]

        service.analyzeSongs(songs)

        #expect(service.allSuggestions.isEmpty) // Different artists, no duplicates
    }

    // MARK: - Active Suggestions Tests

    @Test("Active suggestions sorted by play count difference")
    func activeSuggestionsSorted() {
        let service = makeFreshService()
        let songs = [
            // Group 1: difference of 50
            makeSong(id: 1, title: "Song A", artist: "Artist A", playCount: 100),
            makeSong(id: 2, title: "Song A", artist: "Artist A", playCount: 50),
            // Group 2: difference of 100
            makeSong(id: 3, title: "Song B", artist: "Artist B", playCount: 150),
            makeSong(id: 4, title: "Song B", artist: "Artist B", playCount: 50),
        ]

        service.analyzeSongs(songs)

        let active = service.activeSuggestions
        #expect(active.count == 2)
        #expect(active[0].playCountDifference == 100) // Higher difference first
        #expect(active[1].playCountDifference == 50)
    }

    // MARK: - Active Repair Tests

    @Test("Building a Repair Queue creates an Active Repair and hides its Suggestion", .bug(id: 5))
    func createActiveRepairHidesSuggestion() throws {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Midnight City", artist: "M83", playCount: 140),
            makeSong(id: 2, title: "Midnight City", artist: "M83", playCount: 22),
        ]
        service.analyzeSongs(songs)
        let suggestion = try #require(service.activeSuggestions.first)
        let repairModel = try SuggestionRepairModel(suggestion: suggestion)

        let activeRepair = try service.createActiveRepair(from: repairModel.decision, for: suggestion)

        #expect(service.activeRepairs == [activeRepair])
        #expect(activeRepair.suggestionTitle == "Midnight City")
        #expect(activeRepair.suggestionArtist == "M83")
        #expect(activeRepair.canonicalSong.id == 1)
        #expect(activeRepair.retiredSongs.map(\.id) == [2])
        #expect(activeRepair.repairAmount == 22)
        #expect(service.activeSuggestions.isEmpty)
    }

    @Test("A Suggestion can have at most one Active Repair", .bug(id: 5))
    func rejectsDuplicateActiveRepair() throws {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Midnight City", artist: "M83", playCount: 140),
            makeSong(id: 2, title: "Midnight City", artist: "M83", playCount: 22),
        ]
        service.analyzeSongs(songs)
        let suggestion = try #require(service.activeSuggestions.first)
        let repairModel = try SuggestionRepairModel(suggestion: suggestion)

        _ = try service.createActiveRepair(from: repairModel.decision, for: suggestion)

        #expect(throws: ActiveRepairError.alreadyExists) {
            try service.createActiveRepair(from: repairModel.decision, for: suggestion)
        }
        #expect(service.activeRepairs.count == 1)
    }

    @Test("Active Repair preflight detects duplicate state before queue mutation", .bug(id: 5))
    func detectsExistingActiveRepairBeforeQueueMutation() throws {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Midnight City", artist: "M83", playCount: 140),
            makeSong(id: 2, title: "Midnight City", artist: "M83", playCount: 22),
        ]
        service.analyzeSongs(songs)
        let suggestion = try #require(service.activeSuggestions.first)
        let repairModel = try SuggestionRepairModel(suggestion: suggestion)

        #expect(service.hasActiveRepair(for: suggestion) == false)

        _ = try service.createActiveRepair(from: repairModel.decision, for: suggestion)

        #expect(service.hasActiveRepair(for: suggestion))
    }

    @Test("Active Repair state survives a new service instance", .bug(id: 5))
    func activeRepairSurvivesNewServiceInstance() throws {
        defer {
            UserDefaults.standard.removeObject(forKey: StorageKeys.activeRepairs)
        }

        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Midnight City", artist: "M83", playCount: 140),
            makeSong(id: 2, title: "Midnight City", artist: "M83", playCount: 22),
        ]
        service.analyzeSongs(songs)
        let suggestion = try #require(service.activeSuggestions.first)
        let repairModel = try SuggestionRepairModel(suggestion: suggestion)
        let activeRepair = try service.createActiveRepair(from: repairModel.decision, for: suggestion)

        let restoredService = SuggestionsService()
        restoredService.analyzeSongs(songs)

        #expect(restoredService.activeRepairs == [activeRepair])
        #expect(restoredService.activeSuggestions.isEmpty)
    }

    @Test("Multiple Suggestions can become Active Repairs in one session", .bug(id: 6))
    func createsRepeatedActiveRepairsInOneSession() throws {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Midnight City", artist: "M83", playCount: 140),
            makeSong(id: 2, title: "Midnight City", artist: "M83", playCount: 22),
            makeSong(id: 3, title: "Sweet Disposition", artist: "The Temper Trap", playCount: 98),
            makeSong(id: 4, title: "Sweet Disposition", artist: "The Temper Trap", playCount: 30),
        ]
        service.analyzeSongs(songs)
        let firstSuggestion = try #require(service.activeSuggestions.first { $0.sharedTitle == "Midnight City" })
        let firstRepairModel = try SuggestionRepairModel(suggestion: firstSuggestion)

        let firstActiveRepair = try service.createActiveRepair(from: firstRepairModel.decision, for: firstSuggestion)

        #expect(service.activeRepairs == [firstActiveRepair])
        #expect(service.activeSuggestions.map(\.sharedTitle) == ["Sweet Disposition"])

        let secondSuggestion = try #require(service.activeSuggestions.first)
        let secondRepairModel = try SuggestionRepairModel(suggestion: secondSuggestion)
        let secondActiveRepair = try service.createActiveRepair(from: secondRepairModel.decision, for: secondSuggestion)

        #expect(service.activeRepairs == [firstActiveRepair, secondActiveRepair])
        #expect(service.activeSuggestions.isEmpty)
    }

    // MARK: - Dismissal Tests

    @Test("Dismissing entire group removes from active")
    func dismissEntireGroup() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "Hello", artist: "Adele", playCount: 50),
        ]

        service.analyzeSongs(songs)
        #expect(service.activeSuggestions.count == 1)

        service.dismissEntireGroup(title: "Hello", artist: "Adele")
        #expect(service.activeSuggestions.isEmpty)
    }

    @Test("Dismissing individual song from 3+ group keeps group")
    func dismissIndividualSong() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "Hello", artist: "Adele", playCount: 50),
            makeSong(id: 3, title: "Hello", artist: "Adele", playCount: 25),
        ]

        service.analyzeSongs(songs)
        #expect(service.activeSuggestions[0].songs.count == 3)

        service.dismissSong(title: "Hello", artist: "Adele", songId: 1)

        let active = service.activeSuggestions
        #expect(active.count == 1)
        #expect(active[0].songs.count == 2)
    }

    @Test("Dismissing songs below threshold removes group")
    func dismissBelowThreshold() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "Hello", artist: "Adele", playCount: 50),
            makeSong(id: 3, title: "Hello", artist: "Adele", playCount: 25),
        ]

        service.analyzeSongs(songs)

        // Dismiss two songs, leaving only one
        service.dismissSong(title: "Hello", artist: "Adele", songId: 1)
        service.dismissSong(title: "Hello", artist: "Adele", songId: 2)

        #expect(service.activeSuggestions.isEmpty)
    }

    @Test("Reset dismissals restores all suggestions")
    func resetDismissals() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "Hello", artist: "Adele", playCount: 50),
        ]

        service.analyzeSongs(songs)
        service.dismissEntireGroup(title: "Hello", artist: "Adele")
        #expect(service.activeSuggestions.isEmpty)

        service.resetDismissals()
        #expect(service.activeSuggestions.count == 1)
    }

    // MARK: - Case Insensitivity Tests

    @Test("Dismissal is case insensitive for title")
    func dismissCaseInsensitiveTitle() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "hello", artist: "Adele", playCount: 50),
        ]

        service.analyzeSongs(songs)
        service.dismissEntireGroup(title: "HELLO", artist: "Adele")

        #expect(service.activeSuggestions.isEmpty)
    }

    @Test("Dismissal is case insensitive for artist")
    func dismissCaseInsensitiveArtist() {
        let service = makeFreshService()
        let songs = [
            makeSong(id: 1, title: "Hello", artist: "Adele", playCount: 100),
            makeSong(id: 2, title: "Hello", artist: "ADELE", playCount: 50),
        ]

        service.analyzeSongs(songs)
        service.dismissEntireGroup(title: "Hello", artist: "adele")

        #expect(service.activeSuggestions.isEmpty)
    }
}
