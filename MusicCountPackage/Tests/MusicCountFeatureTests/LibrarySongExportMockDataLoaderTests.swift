import Foundation
import Testing
import UIKit
@testable import MusicCountFeature

@Suite("LibrarySongExportMockDataLoader Tests")
struct LibrarySongExportMockDataLoaderTests {
    @Test("Loads exported Library Songs with artwork", .bug(id: 26))
    func loadsExportedLibrarySongsWithArtwork() throws {
        let exportDirectory = try makeExportDirectory()
        let songs = try #require(LibrarySongExportMockDataLoader.loadSongs(from: exportDirectory))
        let song = try #require(songs.first)

        #expect(songs.count == 1)
        #expect(song.id == 7)
        #expect(song.title == "Alpha")
        #expect(song.artist == "Artist")
        #expect(song.album == "First")
        #expect(song.playCount == 11)
        #expect(song.hasAssetURL)
        #expect(song.mediaType == "Music")
        #expect(song.duration == 120)
        #expect(song.artworkImage != nil)
    }

    private func makeExportDirectory() throws -> URL {
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibrarySongExportMockDataLoaderTests-\(UUID().uuidString)", isDirectory: true)
        let artworkDirectory = exportDirectory.appendingPathComponent("artwork", isDirectory: true)
        try FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)

        let artworkData = try #require(makeArtworkImage().pngData())
        try artworkData.write(to: artworkDirectory.appendingPathComponent("0000000000000007.png"))

        let manifest = PhysicalLibraryExportManifest(
            schemaVersion: 1,
            songs: [
                PhysicalLibraryExportSong(
                    persistentID: "7",
                    persistentIDHex: "0000000000000007",
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
                    hasArtwork: true,
                    artworkPath: "artwork/0000000000000007.png"
                ),
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: exportDirectory.appendingPathComponent("manifest.json"))

        return exportDirectory
    }

    private func makeArtworkImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}
