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
}

@MainActor
private final class FakePlaylistSyncService: SongsToRemovePlaylistSyncing {
    private let error: (any Error)?
    private(set) var syncedActiveRepairCounts: [Int] = []

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func sync(activeRepairs: [ActiveRepair]) async throws {
        syncedActiveRepairCounts.append(activeRepairs.count)

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
