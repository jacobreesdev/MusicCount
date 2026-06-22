#if DEBUG
import SwiftUI

@MainActor
enum MusicCountPreviewData {
    static var librarySongs: [SongInfo] {
        MockScenarioCatalog.librarySongs
    }

    static var activeRepairs: [ActiveRepair] {
        MockScenarioCatalog.activeRepairs
    }

    static var completedRepair: CompletedRepair {
        MockScenarioCatalog.completedRepair
    }

    static var populatedSuggestions: [Suggestion] {
        [
            blindingLightsSuggestion,
            shakeItOffSuggestion,
            blankSpaceSuggestion,
            longMetadataSuggestion,
            zeroPlayCountsSuggestion,
            largeRepairAmountSuggestion,
        ]
    }

    static var blindingLightsSuggestion: Suggestion {
        makeSuggestion(
            title: "Blinding Lights",
            artist: "The Weeknd",
            songIDs: [0, 1, 2, 3]
        )
    }

    static var shakeItOffSuggestion: Suggestion {
        makeSuggestion(
            title: "Shake It Off",
            artist: "Taylor Swift",
            songIDs: [4, 7]
        )
    }

    static var blankSpaceSuggestion: Suggestion {
        makeSuggestion(
            title: "Blank Space",
            artist: "Taylor Swift",
            songIDs: [5, 8]
        )
    }

    static var longMetadataSuggestion: Suggestion {
        makeSuggestion(
            title: "hate that i made you love me",
            artist: "Ari Example",
            songIDs: [10_001, 10_002, 10_003]
        )
    }

    static var zeroPlayCountsSuggestion: Suggestion {
        makeSuggestion(
            title: "Quiet Room",
            artist: "Zero Count Artist",
            songIDs: [10_004, 10_005]
        )
    }

    static var largeRepairAmountSuggestion: Suggestion {
        makeSuggestion(
            title: "Run It Back",
            artist: "Big Gap Band",
            songIDs: [10_006, 10_007, 10_008]
        )
    }

    static var longLibrarySong: SongInfo {
        song(id: 10_003)
    }

    static func defaultRepairModel(for suggestion: Suggestion) -> SuggestionRepairModel {
        do {
            return try SuggestionRepairModel(suggestion: suggestion)
        } catch {
            preconditionFailure("Preview Suggestion should support repair: \(error)")
        }
    }

    static func alternateCanonicalModel() -> SuggestionRepairModel {
        var model = defaultRepairModel(for: blindingLightsSuggestion)
        do {
            try model.chooseCanonicalSong(id: 3)
        } catch {
            preconditionFailure("Preview alternate Canonical Song should be valid: \(error)")
        }
        return model
    }

    static func excludedRetiredSongModel() -> SuggestionRepairModel {
        var model = defaultRepairModel(for: longMetadataSuggestion)
        do {
            try model.setIncludedAsRetired(false, forSongID: 10_003)
        } catch {
            preconditionFailure("Preview excluded Retired Song should be valid: \(error)")
        }
        return model
    }

    private static func makeSuggestion(title: String, artist: String, songIDs: [UInt64]) -> Suggestion {
        Suggestion(
            sharedTitle: title,
            sharedArtist: artist,
            songs: songIDs.map(song(id:))
        )
    }

    private static func song(id: UInt64) -> SongInfo {
        guard let song = librarySongs.first(where: { $0.id == id }) else {
            preconditionFailure("Missing preview Library Song with id \(id).")
        }
        return song
    }
}

@MainActor
private struct MusicCountPreviewEnvironmentModifier: ViewModifier {
    let authorizationState: MusicLibraryService.AuthorizationState
    let loadingState: MusicLibraryService.LoadingState
    let suggestions: [Suggestion]
    let activeRepairs: [ActiveRepair]
    let completedRepairs: [CompletedRepair]
    let playlistSyncProblem: String?

    func body(content: Content) -> some View {
        content
            .environment(musicLibraryService)
            .environment(AppleMusicQueueService())
            .environment(suggestionsService)
            .environment(songsToRemovePlaylistService)
    }

    private var musicLibraryService: MusicLibraryService {
        let service = MockMusicLibraryService()
        service.authorizationState = authorizationState
        service.loadingState = loadingState
        return service
    }

    private var suggestionsService: SuggestionsService {
        let service = SuggestionsService()
        service.replaceStateForPreview(
            allSuggestions: suggestions,
            activeRepairs: activeRepairs,
            completedRepairs: completedRepairs
        )
        return service
    }

    private var songsToRemovePlaylistService: SongsToRemovePlaylistService {
        let service = SongsToRemovePlaylistService(
            client: PreviewSongsToRemovePlaylistClient(),
            store: PreviewSongsToRemovePlaylistStore()
        )
        service.replaceSyncProblemForPreview(playlistSyncProblem)
        return service
    }
}

extension View {
    @MainActor
    func musicCountPreviewEnvironment(
        authorizationState: MusicLibraryService.AuthorizationState = .authorized,
        loadingState: MusicLibraryService.LoadingState? = nil,
        suggestions: [Suggestion]? = nil,
        activeRepairs: [ActiveRepair] = [],
        completedRepairs: [CompletedRepair] = [],
        playlistSyncProblem: String? = nil
    ) -> some View {
        modifier(
            MusicCountPreviewEnvironmentModifier(
                authorizationState: authorizationState,
                loadingState: loadingState ?? .loaded(MusicCountPreviewData.librarySongs),
                suggestions: suggestions ?? MusicCountPreviewData.populatedSuggestions,
                activeRepairs: activeRepairs,
                completedRepairs: completedRepairs,
                playlistSyncProblem: playlistSyncProblem
            )
        )
    }
}

@MainActor
private struct PreviewSongsToRemovePlaylistClient: SongsToRemovePlaylistClient {
    func playlist(id: String) async throws -> SongsToRemovePlaylist? {
        SongsToRemovePlaylist(id: id, name: SongsToRemovePlaylistService.playlistName)
    }

    func createPlaylist(
        name: String,
        description: String,
        authorDisplayName: String,
        songIDs: [UInt64]
    ) async throws -> SongsToRemovePlaylist {
        SongsToRemovePlaylist(id: "preview-songs-to-remove", name: name)
    }

    func replaceItems(in playlist: SongsToRemovePlaylist, with songIDs: [UInt64]) async throws {}
}

private final class PreviewSongsToRemovePlaylistStore: SongsToRemovePlaylistStore {
    var playlistID: String?
}
#endif
