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

        let songs = MockScenarioCatalog.librarySongs(
            artworkMap: artworkMap,
            includingPreviewEdgeCases: false
        )

        NSLog("✅ Generated \(songs.count) mock songs")
        return songs
    }
}
#endif
