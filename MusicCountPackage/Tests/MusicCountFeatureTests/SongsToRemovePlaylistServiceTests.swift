import Foundation
import Testing
@testable import MusicCountFeature

@MainActor
struct SongsToRemovePlaylistServiceTests {
    @Test("Songs to Remove Playlist contains Retired Songs only", .bug(id: 7))
    func syncAddsRetiredSongsOnly() async throws {
        let canonicalSong = makeSong(id: 1, title: "Midnight City", playCount: 140)
        let firstRetiredSong = makeSong(id: 2, title: "Midnight City", playCount: 22)
        let secondRetiredSong = makeSong(id: 3, title: "Midnight City", playCount: 8)
        let activeRepair = makeActiveRepair(
            id: "midnight-city-m83",
            canonicalSong: canonicalSong,
            retiredSongs: [firstRetiredSong, secondRetiredSong]
        )
        let client = FakeSongsToRemovePlaylistClient()
        let store = FakeSongsToRemovePlaylistStore()
        let service = SongsToRemovePlaylistService(client: client, store: store)

        try await service.sync(activeRepairs: [activeRepair])

        #expect(client.createdPlaylists.map(\.songIDs) == [[2, 3]])
        #expect(client.replacedPlaylists.isEmpty)
        #expect(store.playlistID == "playlist-1")
    }

    @Test("Songs to Remove Playlist keeps Retired Songs from multiple Active Repairs", .bug(id: 7))
    func syncKeepsRetiredSongsFromMultipleActiveRepairs() async throws {
        let firstRepair = makeActiveRepair(
            id: "midnight-city-m83",
            canonicalSong: makeSong(id: 1, title: "Midnight City", playCount: 140),
            retiredSongs: [
                makeSong(id: 2, title: "Midnight City", playCount: 22),
                makeSong(id: 3, title: "Midnight City", playCount: 8),
            ]
        )
        let secondRepair = makeActiveRepair(
            id: "sweet-disposition-the-temper-trap",
            canonicalSong: makeSong(id: 4, title: "Sweet Disposition", playCount: 98),
            retiredSongs: [
                makeSong(id: 5, title: "Sweet Disposition", playCount: 30),
            ]
        )
        let client = FakeSongsToRemovePlaylistClient()
        let store = FakeSongsToRemovePlaylistStore()
        let service = SongsToRemovePlaylistService(client: client, store: store)

        try await service.sync(activeRepairs: [firstRepair, secondRepair])

        #expect(client.createdPlaylists.map(\.songIDs) == [[2, 3, 5]])
    }

    @Test("Songs to Remove Playlist finds the stored app-owned playlist", .bug(id: 7))
    func syncFindsStoredPlaylist() async throws {
        let storedPlaylist = SongsToRemovePlaylist(id: "owned-playlist", name: SongsToRemovePlaylistService.playlistName)
        let client = FakeSongsToRemovePlaylistClient(playlists: [storedPlaylist])
        let store = FakeSongsToRemovePlaylistStore(playlistID: storedPlaylist.id)
        let activeRepair = makeActiveRepair(
            id: "midnight-city-m83",
            canonicalSong: makeSong(id: 1, title: "Midnight City", playCount: 140),
            retiredSongs: [makeSong(id: 2, title: "Midnight City", playCount: 22)]
        )
        let service = SongsToRemovePlaylistService(client: client, store: store)

        try await service.sync(activeRepairs: [activeRepair])

        #expect(client.createdPlaylists.isEmpty)
        #expect(client.replacedPlaylists == [
            .init(playlistID: "owned-playlist", songIDs: [2])
        ])
    }

    @Test("Songs to Remove Playlist does not edit an unowned playlist with the same name", .bug(id: 7))
    func syncDoesNotEditUnownedPlaylistWithSameName() async throws {
        let unownedPlaylist = SongsToRemovePlaylist(id: "user-playlist", name: SongsToRemovePlaylistService.playlistName)
        let client = FakeSongsToRemovePlaylistClient(playlists: [unownedPlaylist])
        let store = FakeSongsToRemovePlaylistStore()
        let activeRepair = makeActiveRepair(
            id: "midnight-city-m83",
            canonicalSong: makeSong(id: 1, title: "Midnight City", playCount: 140),
            retiredSongs: [makeSong(id: 2, title: "Midnight City", playCount: 22)]
        )
        let service = SongsToRemovePlaylistService(client: client, store: store)

        try await service.sync(activeRepairs: [activeRepair])

        #expect(client.replacedPlaylists.isEmpty)
        #expect(client.createdPlaylists.map(\.songIDs) == [[2]])
        #expect(store.playlistID == "playlist-1")
    }

    @Test("Songs to Remove Playlist clears the stored playlist when no Active Repairs remain", .bug(id: 7))
    func syncClearsStoredPlaylistWhenNoActiveRepairsRemain() async throws {
        let storedPlaylist = SongsToRemovePlaylist(id: "owned-playlist", name: SongsToRemovePlaylistService.playlistName)
        let client = FakeSongsToRemovePlaylistClient(playlists: [storedPlaylist])
        let store = FakeSongsToRemovePlaylistStore(playlistID: storedPlaylist.id)
        let service = SongsToRemovePlaylistService(client: client, store: store)

        try await service.sync(activeRepairs: [])

        #expect(client.createdPlaylists.isEmpty)
        #expect(client.replacedPlaylists == [
            .init(playlistID: "owned-playlist", songIDs: [])
        ])
        #expect(store.playlistID == "owned-playlist")
    }

    @Test("Songs to Remove Playlist removes Retired Songs from Completed Repairs", .bug(id: 8))
    func syncRemovesRetiredSongsFromCompletedRepairs() async throws {
        let storedPlaylist = SongsToRemovePlaylist(id: "owned-playlist", name: SongsToRemovePlaylistService.playlistName)
        let client = FakeSongsToRemovePlaylistClient(playlists: [storedPlaylist])
        let store = FakeSongsToRemovePlaylistStore(playlistID: storedPlaylist.id)
        let outstandingRepair = makeActiveRepair(
            id: "sweet-disposition-the-temper-trap",
            canonicalSong: makeSong(id: 4, title: "Sweet Disposition", playCount: 98),
            retiredSongs: [makeSong(id: 5, title: "Sweet Disposition", playCount: 30)]
        )
        let service = SongsToRemovePlaylistService(client: client, store: store)

        try await service.sync(activeRepairs: [outstandingRepair])

        #expect(client.replacedPlaylists == [
            .init(playlistID: "owned-playlist", songIDs: [5])
        ])
        #expect(client.createdPlaylists.isEmpty)
    }

    @Test("Music item ID resolver keeps Retired Song order", .bug(id: 7))
    func musicItemIDResolverKeepsRetiredSongOrder() throws {
        let resolver = SongsToRemoveMusicItemIDResolver(
            mediaLibrary: FakeSongsToRemoveMediaLibrary(
                playbackStoreIDsByPersistentID: [
                    2: "store-2",
                    3: "store-3",
                ]
            )
        )

        let itemIDs = try resolver.musicItemIDs(for: [3, 2])

        #expect(itemIDs.map(\.rawValue) == ["store-3", "store-2"])
    }

    @Test("Music item ID resolver rejects local-only Retired Songs", .bug(id: 7))
    func musicItemIDResolverRejectsPlaybackStoreIDZero() throws {
        let resolver = SongsToRemoveMusicItemIDResolver(
            mediaLibrary: FakeSongsToRemoveMediaLibrary(
                playbackStoreIDsByPersistentID: [
                    2: "0",
                ]
            )
        )

        do {
            _ = try resolver.musicItemIDs(for: [2])
            Issue.record("Expected local-only Retired Song to be reported as missing.")
        } catch let error as SongsToRemovePlaylistError {
            #expect(error == .missingLibrarySongs([2]))
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    private func makeSong(id: UInt64, title: String, playCount: Int) -> SongInfo {
        SongInfo(
            id: id,
            title: title,
            artist: "Test Artist",
            album: "Test Album",
            playCount: playCount,
            hasAssetURL: true,
            mediaType: "Music",
            duration: 200
        )
    }

    private func makeActiveRepair(
        id: String,
        canonicalSong: SongInfo,
        retiredSongs: [SongInfo]
    ) -> ActiveRepair {
        ActiveRepair(
            id: id,
            suggestionTitle: canonicalSong.title,
            suggestionArtist: canonicalSong.artist,
            canonicalSong: canonicalSong,
            retiredSongs: retiredSongs,
            repairAmount: retiredSongs.reduce(0) { $0 + $1.playCount }
        )
    }
}

@MainActor
private final class FakeSongsToRemovePlaylistClient: SongsToRemovePlaylistClient {
    struct CreatedPlaylist: Equatable {
        let name: String
        let songIDs: [UInt64]
    }

    struct ReplacedPlaylist: Equatable {
        let playlistID: String
        let songIDs: [UInt64]
    }

    private var playlistsByID: [String: SongsToRemovePlaylist]
    private var nextPlaylistNumber = 1
    private(set) var createdPlaylists: [CreatedPlaylist] = []
    private(set) var replacedPlaylists: [ReplacedPlaylist] = []

    init(playlists: [SongsToRemovePlaylist] = []) {
        playlistsByID = Dictionary(uniqueKeysWithValues: playlists.map { ($0.id, $0) })
    }

    func playlist(id: String) async throws -> SongsToRemovePlaylist? {
        playlistsByID[id]
    }

    func createPlaylist(
        name: String,
        description: String,
        authorDisplayName: String,
        songIDs: [UInt64]
    ) async throws -> SongsToRemovePlaylist {
        let playlist = SongsToRemovePlaylist(id: "playlist-\(nextPlaylistNumber)", name: name)
        nextPlaylistNumber += 1
        playlistsByID[playlist.id] = playlist
        createdPlaylists.append(.init(name: name, songIDs: songIDs))
        return playlist
    }

    func replaceItems(in playlist: SongsToRemovePlaylist, with songIDs: [UInt64]) async throws {
        replacedPlaylists.append(.init(playlistID: playlist.id, songIDs: songIDs))
    }
}

private final class FakeSongsToRemovePlaylistStore: SongsToRemovePlaylistStore {
    var playlistID: String?

    init(playlistID: String? = nil) {
        self.playlistID = playlistID
    }
}

@MainActor
private struct FakeSongsToRemoveMediaLibrary: SongsToRemoveMediaLibrary {
    let playbackStoreIDsByPersistentID: [UInt64: String]

    func playbackStoreIDs(for songIDs: Set<UInt64>) -> [UInt64: String] {
        playbackStoreIDsByPersistentID.filter { songIDs.contains($0.key) }
    }
}
