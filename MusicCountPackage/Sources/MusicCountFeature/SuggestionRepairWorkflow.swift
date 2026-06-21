import Foundation

@MainActor
protocol RepairQueueAdding: AnyObject {
    func addToQueue(song: SongInfo, count: Int) throws
}

extension AppleMusicQueueService: RepairQueueAdding {}

@MainActor
protocol ActiveRepairManaging: AnyObject {
    var activeRepairs: [ActiveRepair] { get }

    func createActiveRepair(from decision: RepairDecision, for suggestion: Suggestion) throws -> ActiveRepair
    func hasActiveRepair(for suggestion: Suggestion) -> Bool
    func markActiveRepairDone(id: String) throws -> CompletedRepair
}

extension SuggestionsService: ActiveRepairManaging {}

@MainActor
protocol SongsToRemovePlaylistSyncing: AnyObject {
    func sync(activeRepairs: [ActiveRepair]) async throws
}

extension SongsToRemovePlaylistService: SongsToRemovePlaylistSyncing {}

enum SongsToRemovePlaylistSyncResult: Equatable, Sendable {
    case synced
    case failed(message: String)
}

struct SuggestionRepairWorkflowResult: Equatable, Sendable {
    let activeRepair: ActiveRepair
    let playlistSync: SongsToRemovePlaylistSyncResult
}

struct ActiveRepairCompletionWorkflowResult: Equatable, Sendable {
    let completedRepair: CompletedRepair
    let playlistSync: SongsToRemovePlaylistSyncResult
}

@MainActor
struct ActiveRepairPlaylistSyncWorkflow {
    private let suggestionsService: any ActiveRepairManaging
    private let songsToRemovePlaylistService: any SongsToRemovePlaylistSyncing

    init(
        suggestionsService: any ActiveRepairManaging,
        songsToRemovePlaylistService: any SongsToRemovePlaylistSyncing
    ) {
        self.suggestionsService = suggestionsService
        self.songsToRemovePlaylistService = songsToRemovePlaylistService
    }

    func resyncSongsToRemovePlaylist() async -> SongsToRemovePlaylistSyncResult {
        do {
            try await songsToRemovePlaylistService.sync(activeRepairs: suggestionsService.activeRepairs)
            return .synced
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }
}

@MainActor
struct SuggestionRepairWorkflow {
    private let queueService: any RepairQueueAdding
    private let suggestionsService: any ActiveRepairManaging
    private let songsToRemovePlaylistService: any SongsToRemovePlaylistSyncing

    init(
        queueService: any RepairQueueAdding,
        suggestionsService: any ActiveRepairManaging,
        songsToRemovePlaylistService: any SongsToRemovePlaylistSyncing
    ) {
        self.queueService = queueService
        self.suggestionsService = suggestionsService
        self.songsToRemovePlaylistService = songsToRemovePlaylistService
    }

    func buildRepairQueue(
        decision: RepairDecision,
        for suggestion: Suggestion
    ) async throws -> SuggestionRepairWorkflowResult {
        try queueService.addToQueue(song: decision.canonicalSong, count: decision.repairAmount)
        let activeRepair = try suggestionsService.createActiveRepair(from: decision, for: suggestion)

        let playlistSync = await ActiveRepairPlaylistSyncWorkflow(
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: songsToRemovePlaylistService
        ).resyncSongsToRemovePlaylist()

        return SuggestionRepairWorkflowResult(activeRepair: activeRepair, playlistSync: playlistSync)
    }
}

@MainActor
struct ActiveRepairCompletionWorkflow {
    private let suggestionsService: any ActiveRepairManaging
    private let songsToRemovePlaylistService: any SongsToRemovePlaylistSyncing

    init(
        suggestionsService: any ActiveRepairManaging,
        songsToRemovePlaylistService: any SongsToRemovePlaylistSyncing
    ) {
        self.suggestionsService = suggestionsService
        self.songsToRemovePlaylistService = songsToRemovePlaylistService
    }

    func markActiveRepairDone(id: String) async throws -> ActiveRepairCompletionWorkflowResult {
        let completedRepair = try suggestionsService.markActiveRepairDone(id: id)

        let playlistSync = await ActiveRepairPlaylistSyncWorkflow(
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: songsToRemovePlaylistService
        ).resyncSongsToRemovePlaylist()

        return ActiveRepairCompletionWorkflowResult(completedRepair: completedRepair, playlistSync: playlistSync)
    }
}
