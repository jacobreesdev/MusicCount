import Foundation
import MediaPlayer
import MusicKit
import Observation

struct SongsToRemovePlaylist: Equatable, Sendable {
    let id: String
    let name: String
}

struct SongsToRemovePlaylistSyncProblem: Equatable, Sendable {
    let message: String
}

@MainActor
protocol SongsToRemovePlaylistClient {
    func playlist(id: String) async throws -> SongsToRemovePlaylist?
    func createPlaylist(
        name: String,
        description: String,
        authorDisplayName: String,
        songIDs: [UInt64]
    ) async throws -> SongsToRemovePlaylist
    func replaceItems(in playlist: SongsToRemovePlaylist, with songIDs: [UInt64]) async throws
}

protocol SongsToRemovePlaylistStore: AnyObject {
    var playlistID: String? { get set }
}

@MainActor
protocol SongsToRemoveMediaLibrary {
    func playbackStoreIDs(for songIDs: Set<UInt64>) -> [UInt64: String]
}

@MainActor
struct MPMediaSongsToRemoveMediaLibrary: SongsToRemoveMediaLibrary {
    func playbackStoreIDs(for songIDs: Set<UInt64>) -> [UInt64: String] {
        let query = MPMediaQuery.songs()
        return Dictionary(
            uniqueKeysWithValues: (query.items ?? []).compactMap { item -> (UInt64, String)? in
                let persistentID = item.persistentID
                guard songIDs.contains(persistentID) else { return nil }

                let playbackStoreID = item.playbackStoreID
                guard playbackStoreID.isEmpty == false, playbackStoreID != "0" else { return nil }

                return (persistentID, playbackStoreID)
            }
        )
    }
}

@MainActor
struct SongsToRemoveMusicItemIDResolver {
    private let mediaLibrary: any SongsToRemoveMediaLibrary

    init(mediaLibrary: any SongsToRemoveMediaLibrary = MPMediaSongsToRemoveMediaLibrary()) {
        self.mediaLibrary = mediaLibrary
    }

    func musicItemIDs(for songIDs: [UInt64]) throws -> [MusicItemID] {
        guard songIDs.isEmpty == false else { return [] }

        let playbackStoreIDsByPersistentID = mediaLibrary
            .playbackStoreIDs(for: Set(songIDs))
            .filter { Self.isValidPlaybackStoreID($0.value) }
        let missingSongIDs = songIDs.filter { playbackStoreIDsByPersistentID[$0] == nil }
        guard missingSongIDs.isEmpty else {
            throw SongsToRemovePlaylistError.missingLibrarySongs(missingSongIDs)
        }

        return songIDs.compactMap { songID in
            playbackStoreIDsByPersistentID[songID].map { MusicItemID($0) }
        }
    }

    private static func isValidPlaybackStoreID(_ playbackStoreID: String) -> Bool {
        playbackStoreID.isEmpty == false && playbackStoreID != "0"
    }
}

final class UserDefaultsSongsToRemovePlaylistStore: SongsToRemovePlaylistStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = StorageKeys.songsToRemovePlaylistID
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    var playlistID: String? {
        get {
            userDefaults.string(forKey: key)
        }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}

enum SongsToRemovePlaylistError: Error, Equatable, LocalizedError, Sendable {
    case missingLibrarySongs([UInt64])
    case playlistNotFound(String)

    var errorDescription: String? {
        switch self {
        case .missingLibrarySongs(let ids):
            let idList = ids.map(String.init).joined(separator: ", ")
            return "Some Retired Songs could not be found in your Apple Music library: \(idList)."
        case .playlistNotFound:
            return "MusicCount could not find its Songs to Remove Playlist."
        }
    }
}

/// Keeps the app-owned Songs to Remove Playlist aligned with outstanding Active Repairs.
@MainActor
@Observable
final class SongsToRemovePlaylistService {
    static let playlistName = "MusicCount Songs to Remove"
    static let playlistDescription = "Retired Songs from MusicCount Active Repairs."
    static let authorDisplayName = "MusicCount"

    @ObservationIgnored private let client: any SongsToRemovePlaylistClient
    @ObservationIgnored private let store: any SongsToRemovePlaylistStore
    private(set) var syncProblem: SongsToRemovePlaylistSyncProblem?

    init(
        client: any SongsToRemovePlaylistClient = MusicKitSongsToRemovePlaylistClient(),
        store: any SongsToRemovePlaylistStore = UserDefaultsSongsToRemovePlaylistStore()
    ) {
        self.client = client
        self.store = store
    }

    func sync(activeRepairs: [ActiveRepair]) async throws {
        do {
            try await syncPlaylist(activeRepairs: activeRepairs)
            syncProblem = nil
        } catch {
            syncProblem = SongsToRemovePlaylistSyncProblem(message: error.localizedDescription)
            throw error
        }
    }

    private func syncPlaylist(activeRepairs: [ActiveRepair]) async throws {
        let songIDs = retiredSongIDs(from: activeRepairs)

        if let storedPlaylistID = store.playlistID {
            if let playlist = try await client.playlist(id: storedPlaylistID) {
                do {
                    try await client.replaceItems(in: playlist, with: songIDs)
                    return
                } catch let error as SongsToRemovePlaylistError {
                    guard case .playlistNotFound = error else { throw error }
                    store.playlistID = nil
                }
            } else {
                store.playlistID = nil
            }
        }

        guard songIDs.isEmpty == false else { return }

        let playlist = try await client.createPlaylist(
            name: Self.playlistName,
            description: Self.playlistDescription,
            authorDisplayName: Self.authorDisplayName,
            songIDs: songIDs
        )
        store.playlistID = playlist.id
    }

    private func retiredSongIDs(from activeRepairs: [ActiveRepair]) -> [UInt64] {
        var seenSongIDs: Set<UInt64> = []
        var orderedSongIDs: [UInt64] = []

        for activeRepair in activeRepairs {
            for retiredSong in activeRepair.retiredSongs where seenSongIDs.insert(retiredSong.id).inserted {
                orderedSongIDs.append(retiredSong.id)
            }
        }

        return orderedSongIDs
    }
}

@MainActor
struct MusicKitSongsToRemovePlaylistClient: SongsToRemovePlaylistClient {
    private let itemIDResolver: SongsToRemoveMusicItemIDResolver

    init(itemIDResolver: SongsToRemoveMusicItemIDResolver = SongsToRemoveMusicItemIDResolver()) {
        self.itemIDResolver = itemIDResolver
    }

    func playlist(id: String) async throws -> SongsToRemovePlaylist? {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 1
        request.filter(matching: \.id, equalTo: MusicItemID(id))

        let response = try await request.response()
        guard let playlist = response.items.first else { return nil }
        return SongsToRemovePlaylist(id: playlist.id.rawValue, name: playlist.name)
    }

    func createPlaylist(
        name: String,
        description: String,
        authorDisplayName: String,
        songIDs: [UInt64]
    ) async throws -> SongsToRemovePlaylist {
        let songs = try await musicKitSongs(for: songIDs)
        let playlist: Playlist

        if songs.isEmpty {
            playlist = try await MusicLibrary.shared.createPlaylist(
                name: name,
                description: description,
                authorDisplayName: authorDisplayName
            )
        } else {
            playlist = try await MusicLibrary.shared.createPlaylist(
                name: name,
                description: description,
                authorDisplayName: authorDisplayName,
                items: songs
            )
        }

        return SongsToRemovePlaylist(id: playlist.id.rawValue, name: playlist.name)
    }

    func replaceItems(in playlist: SongsToRemovePlaylist, with songIDs: [UInt64]) async throws {
        guard let musicKitPlaylist = try await musicKitPlaylist(id: playlist.id) else {
            throw SongsToRemovePlaylistError.playlistNotFound(playlist.id)
        }

        let songs = try await musicKitSongs(for: songIDs)
        _ = try await MusicLibrary.shared.edit(
            musicKitPlaylist,
            name: nil,
            description: nil,
            authorDisplayName: nil,
            items: songs
        )
    }

    private func musicKitPlaylist(id: String) async throws -> Playlist? {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 1
        request.filter(matching: \.id, equalTo: MusicItemID(id))
        return try await request.response().items.first
    }

    private func musicKitSongs(for songIDs: [UInt64]) async throws -> [Song] {
        let itemIDs = try itemIDResolver.musicItemIDs(for: songIDs)
        guard itemIDs.isEmpty == false else { return [] }

        var request = MusicLibraryRequest<Song>()
        request.limit = itemIDs.count
        request.filter(matching: \.id, memberOf: itemIDs)

        let songs = Array(try await request.response().items)
        let songsByID = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        let orderedSongs = itemIDs.compactMap { songsByID[$0] }

        guard orderedSongs.count == itemIDs.count else {
            let foundIDs = Set(songs.map(\.id))
            let missingSongIDs = zip(songIDs, itemIDs).compactMap { songID, itemID in
                foundIDs.contains(itemID) ? nil : songID
            }
            throw SongsToRemovePlaylistError.missingLibrarySongs(missingSongIDs)
        }

        return orderedSongs
    }
}
