import Foundation
import Testing
@testable import MusicCountFeature

@MainActor
struct SuggestionRepairWorkflowTests {
    @Test("Repair Queue build succeeds when Songs to Remove Playlist sync fails", .bug(id: 7))
    func buildRepairQueueSucceedsWhenPlaylistSyncFails() async throws {
        let suggestion = makeSuggestion()
        let decision = try RepairDecision(
            duplicateGroup: suggestion.songs,
            canonicalSongID: 1
        )
        let queueService = FakeRepairQueueService()
        let suggestionsService = FakeActiveRepairStore()
        let playlistService = FakePlaylistSyncService(error: TestPlaylistSyncError.unavailable)
        let workflow = SuggestionRepairWorkflow(
            queueService: queueService,
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: playlistService
        )

        let result = try await workflow.buildRepairQueue(decision: decision, for: suggestion)

        #expect(queueService.queuedSongs == [.init(songID: 1, count: 22)])
        #expect(suggestionsService.activeRepairs.map(\.id) == ["midnight city-m83"])
        #expect(playlistService.syncedActiveRepairCounts == [1])
        #expect(result.playlistSync == .failed(message: "Playlist sync unavailable."))
    }

    @Test("Repair Queue failure prevents Active Repair creation", .bug(id: 7))
    func queueFailurePreventsActiveRepairCreation() async throws {
        let suggestion = makeSuggestion()
        let decision = try RepairDecision(
            duplicateGroup: suggestion.songs,
            canonicalSongID: 1
        )
        let queueService = FakeRepairQueueService(error: TestQueueError.failed)
        let suggestionsService = FakeActiveRepairStore()
        let playlistService = FakePlaylistSyncService()
        let workflow = SuggestionRepairWorkflow(
            queueService: queueService,
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: playlistService
        )

        do {
            _ = try await workflow.buildRepairQueue(decision: decision, for: suggestion)
            Issue.record("Expected queue failure to be thrown.")
        } catch TestQueueError.failed {
            #expect(suggestionsService.activeRepairs.isEmpty)
            #expect(playlistService.syncedActiveRepairCounts.isEmpty)
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test("Completing an Active Repair syncs the Songs to Remove Playlist from outstanding Active Repairs", .bug(id: 8))
    func completingActiveRepairSyncsPlaylistFromOutstandingActiveRepairs() async throws {
        let completedRepairID = "midnight-city-m83"
        let remainingRepairID = "sweet-disposition-the-temper-trap"
        let completedActiveRepair = makeActiveRepair(id: completedRepairID, title: "Midnight City", retiredSongID: 2)
        let remainingActiveRepair = makeActiveRepair(id: remainingRepairID, title: "Sweet Disposition", retiredSongID: 4)
        let suggestionsService = FakeActiveRepairStore(activeRepairs: [completedActiveRepair, remainingActiveRepair])
        let playlistService = FakePlaylistSyncService()
        let workflow = ActiveRepairCompletionWorkflow(
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: playlistService
        )

        let result = try await workflow.markActiveRepairDone(id: completedRepairID)

        #expect(result.completedRepair.id == completedRepairID)
        #expect(suggestionsService.activeRepairs.map(\.id) == [remainingRepairID])
        #expect(playlistService.syncedActiveRepairIDs == [[remainingRepairID]])
        #expect(result.playlistSync == .synced)
    }

    @Test("Completion succeeds when Songs to Remove Playlist sync fails", .bug(id: 8))
    func completingActiveRepairSucceedsWhenPlaylistSyncFails() async throws {
        let activeRepair = makeActiveRepair(id: "midnight-city-m83", title: "Midnight City", retiredSongID: 2)
        let suggestionsService = FakeActiveRepairStore(activeRepairs: [activeRepair])
        let playlistService = FakePlaylistSyncService(error: TestPlaylistSyncError.unavailable)
        let workflow = ActiveRepairCompletionWorkflow(
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: playlistService
        )

        let result = try await workflow.markActiveRepairDone(id: activeRepair.id)

        #expect(result.completedRepair.id == activeRepair.id)
        #expect(suggestionsService.activeRepairs.isEmpty)
        #expect(suggestionsService.completedRepairs.map(\.id) == [activeRepair.id])
        #expect(playlistService.syncedActiveRepairIDs == [[]])
        #expect(result.playlistSync == .failed(message: "Playlist sync unavailable."))
    }

    @Test("Retrying Songs to Remove Playlist sync uses outstanding Active Repairs", .bug(id: 20))
    func retryingPlaylistSyncUsesOutstandingActiveRepairs() async {
        let firstRepair = makeActiveRepair(id: "midnight-city-m83", title: "Midnight City", retiredSongID: 2)
        let secondRepair = makeActiveRepair(id: "sweet-disposition-the-temper-trap", title: "Sweet Disposition", retiredSongID: 4)
        let suggestionsService = FakeActiveRepairStore(activeRepairs: [firstRepair, secondRepair])
        let playlistService = FakePlaylistSyncService()
        let workflow = ActiveRepairPlaylistSyncWorkflow(
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: playlistService
        )

        let result = await workflow.resyncSongsToRemovePlaylist()

        #expect(result == .synced)
        #expect(playlistService.syncedActiveRepairIDs == [[firstRepair.id, secondRepair.id]])
        #expect(suggestionsService.activeRepairs == [firstRepair, secondRepair])
        #expect(suggestionsService.completedRepairs.isEmpty)
    }

    @Test("Retrying Songs to Remove Playlist sync reports failure without changing Active Repairs", .bug(id: 20))
    func retryingPlaylistSyncReportsFailureWithoutChangingActiveRepairs() async {
        let activeRepair = makeActiveRepair(id: "midnight-city-m83", title: "Midnight City", retiredSongID: 2)
        let suggestionsService = FakeActiveRepairStore(activeRepairs: [activeRepair])
        let playlistService = FakePlaylistSyncService(error: TestPlaylistSyncError.unavailable)
        let workflow = ActiveRepairPlaylistSyncWorkflow(
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: playlistService
        )

        let result = await workflow.resyncSongsToRemovePlaylist()

        #expect(result == .failed(message: "Playlist sync unavailable."))
        #expect(playlistService.syncedActiveRepairIDs == [[activeRepair.id]])
        #expect(suggestionsService.activeRepairs == [activeRepair])
    }

    private func makeSuggestion() -> Suggestion {
        Suggestion(
            sharedTitle: "Midnight City",
            sharedArtist: "M83",
            songs: [
                makeSong(id: 1, playCount: 140),
                makeSong(id: 2, playCount: 22),
            ]
        )
    }

    private func makeSong(id: UInt64, playCount: Int) -> SongInfo {
        SongInfo(
            id: id,
            title: "Midnight City",
            artist: "M83",
            album: "Test Album",
            playCount: playCount,
            hasAssetURL: true,
            mediaType: "Music",
            duration: 200
        )
    }

    private func makeActiveRepair(id: String, title: String, retiredSongID: UInt64) -> ActiveRepair {
        let canonicalSong = makeSong(id: retiredSongID - 1, playCount: 140)
        let retiredSong = makeSong(id: retiredSongID, playCount: 22)

        return ActiveRepair(
            id: id,
            suggestionTitle: title,
            suggestionArtist: "Test Artist",
            canonicalSong: canonicalSong,
            retiredSongs: [retiredSong],
            repairAmount: retiredSong.playCount
        )
    }
}

@MainActor
private final class FakeRepairQueueService: RepairQueueAdding {
    struct QueuedSong: Equatable {
        let songID: UInt64
        let count: Int
    }

    private let error: (any Error)?
    private(set) var queuedSongs: [QueuedSong] = []

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func addToQueue(song: SongInfo, count: Int) throws {
        if let error {
            throw error
        }

        queuedSongs.append(.init(songID: song.id, count: count))
    }
}

@MainActor
private final class FakeActiveRepairStore: ActiveRepairManaging {
    private(set) var activeRepairs: [ActiveRepair] = []
    private(set) var completedRepairs: [CompletedRepair] = []

    init(activeRepairs: [ActiveRepair] = []) {
        self.activeRepairs = activeRepairs
    }

    func createActiveRepair(from decision: RepairDecision, for suggestion: Suggestion) throws -> ActiveRepair {
        guard hasActiveRepair(for: suggestion) == false else {
            throw ActiveRepairError.alreadyExists
        }

        let activeRepair = ActiveRepair(
            id: "\(suggestion.sharedTitle.lowercased())-\(suggestion.sharedArtist.lowercased())",
            suggestionTitle: suggestion.sharedTitle,
            suggestionArtist: suggestion.sharedArtist,
            canonicalSong: decision.canonicalSong,
            retiredSongs: decision.retiredSongs,
            repairAmount: decision.repairAmount
        )
        activeRepairs.append(activeRepair)
        return activeRepair
    }

    func hasActiveRepair(for suggestion: Suggestion) -> Bool {
        activeRepairs.contains {
            $0.suggestionTitle == suggestion.sharedTitle &&
                $0.suggestionArtist == suggestion.sharedArtist
        }
    }

    func markActiveRepairDone(id: String) throws -> CompletedRepair {
        guard let activeRepairIndex = activeRepairs.firstIndex(where: { $0.id == id }) else {
            throw ActiveRepairError.notFound
        }

        let activeRepair = activeRepairs.remove(at: activeRepairIndex)
        let completedRepair = CompletedRepair(activeRepair: activeRepair)
        completedRepairs.append(completedRepair)
        return completedRepair
    }
}

@MainActor
private final class FakePlaylistSyncService: SongsToRemovePlaylistSyncing {
    private let error: (any Error)?
    private(set) var syncedActiveRepairCounts: [Int] = []
    private(set) var syncedActiveRepairIDs: [[String]] = []

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func sync(activeRepairs: [ActiveRepair]) async throws {
        syncedActiveRepairCounts.append(activeRepairs.count)
        syncedActiveRepairIDs.append(activeRepairs.map(\.id))

        if let error {
            throw error
        }
    }
}

private enum TestQueueError: Error {
    case failed
}

private enum TestPlaylistSyncError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Playlist sync unavailable."
    }
}
