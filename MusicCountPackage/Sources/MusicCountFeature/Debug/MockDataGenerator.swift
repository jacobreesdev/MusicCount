#if DEBUG
import Foundation
import UIKit

/// Generates SongInfo objects from the debug Library.xml export or fallback mock data.
@MainActor
final class MockDataGenerator {
    private let artworkFetcher = AlbumArtworkFetcher()

    /// Generate complete mock library data.
    /// - Returns: Array of SongInfo objects ready for display
    func generateMockLibrary() async -> [SongInfo] {
        if let exportedSongs = LibrarySongExportMockDataLoader.loadSongsFromLaunchConfiguration() {
            NSLog("Generated \(exportedSongs.count) mock songs from exported Library Song manifest")
            return exportedSongs
        }

        if let exportedSongs = LibraryXMLMockDataLoader.loadSongs() {
            NSLog("Generated \(exportedSongs.count) mock songs from Library.xml")
            return exportedSongs
        }

        NSLog("📀 Generating mock library with real album artwork...")

        // Fetch all album artwork in parallel
        let uniqueAlbums = MockSongData.uniqueAlbums
        NSLog("🎨 Fetching artwork for \(uniqueAlbums.count) unique albums...")

        let artworkMap = await artworkFetcher.fetchAllArtwork(for: uniqueAlbums)
        NSLog("✅ Fetched \(artworkMap.count) album artworks")

        // Convert mock songs to SongInfo with artwork
        let songs = MockSongData.songs.enumerated().map { (index, mockSong) -> SongInfo in
            let artworkKey = "\(mockSong.artist)|\(mockSong.album)"
            let artwork = artworkMap[artworkKey]

            return SongInfo(
                id: UInt64(index),
                title: mockSong.title,
                artist: mockSong.artist,
                album: mockSong.album,
                playCount: mockSong.playCount,
                hasAssetURL: true,
                mediaType: "Music",
                duration: mockSong.duration,
                artworkImage: artwork
            )
        }

        NSLog("✅ Generated \(songs.count) mock songs")
        return songs
    }
}
#endif
