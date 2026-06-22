import Foundation
import Testing
@testable import MusicCountFeature

@Suite("Physical Library Export Manifest Tests")
struct PhysicalLibraryExportManifestTests {
    @Test("Builds deterministic Library Song export JSON", .bug(id: 26))
    func buildsDeterministicLibrarySongExportJSON() throws {
        let songs = [
            PhysicalLibraryExportSongInput(
                persistentID: 42,
                title: "Beta",
                artist: "Artist",
                album: "Second",
                albumArtist: nil,
                genre: "",
                duration: 180,
                playCount: 7,
                mediaType: "Music",
                hasLocalAsset: false,
                isCloudItem: true,
                playbackStoreID: "",
                hasArtwork: false
            ),
            PhysicalLibraryExportSongInput(
                persistentID: 7,
                title: "Alpha",
                artist: "Artist",
                album: "First",
                albumArtist: "Album Artist",
                genre: "Pop",
                duration: 120,
                playCount: 11,
                mediaType: "Music",
                hasLocalAsset: true,
                isCloudItem: false,
                playbackStoreID: "1234567890",
                hasArtwork: true
            ),
        ]

        let manifestData = try PhysicalLibraryExportManifestBuilder.makeManifestData(from: songs)
        let manifest = try JSONDecoder().decode(PhysicalLibraryExportManifest.self, from: manifestData)

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.songs.map(\.persistentID) == ["7", "42"])
        #expect(manifest.songs.map(\.persistentIDHex) == ["0000000000000007", "000000000000002A"])

        let firstSong = try #require(manifest.songs.first)
        #expect(firstSong.title == "Alpha")
        #expect(firstSong.albumArtist == "Album Artist")
        #expect(firstSong.genre == "Pop")
        #expect(firstSong.playCount == 11)
        #expect(firstSong.hasLocalAsset)
        #expect(firstSong.isCloudItem == false)
        #expect(firstSong.playbackStoreID == "1234567890")
        #expect(firstSong.hasArtwork)
        #expect(firstSong.artworkPath == "artwork/0000000000000007.png")

        let secondSong = try #require(manifest.songs.last)
        #expect(secondSong.title == "Beta")
        #expect(secondSong.genre == nil)
        #expect(secondSong.playbackStoreID == nil)
        #expect(secondSong.hasArtwork == false)
        #expect(secondSong.artworkPath == nil)
    }
}
