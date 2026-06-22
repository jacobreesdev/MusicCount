#if DEBUG
import Foundation
import UIKit

enum LibrarySongExportMockDataLoader {
    static func loadSongsFromLaunchConfiguration(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [SongInfo]? {
        guard let exportURL = exportURL(arguments: arguments, environment: environment) else {
            return nil
        }

        return loadSongs(from: exportURL)
    }

    static func loadSongs(from exportDirectory: URL) -> [SongInfo]? {
        let manifestURL = exportDirectory.appendingPathComponent("manifest.json")

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(PhysicalLibraryExportManifest.self, from: data)
            let songs = manifest.songs.compactMap { songInfo(from: $0, exportDirectory: exportDirectory) }
            return songs.isEmpty ? nil : songs
        } catch {
            NSLog("Could not load exported Library Song mock data from \(manifestURL.path): \(error.localizedDescription)")
            return nil
        }
    }

    private static func exportURL(arguments: [String], environment: [String: String]) -> URL? {
        if let path = environment["MUSICCOUNT_MOCK_EXPORT_PATH"], path.isEmpty == false {
            return URL(fileURLWithPath: path)
        }

        if let argument = arguments.first(where: { $0.hasPrefix("MockDataExportPath=") }) {
            return URL(fileURLWithPath: String(argument.dropFirst("MockDataExportPath=".count)))
        }

        if
            let flagIndex = arguments.firstIndex(of: "-MockDataExportPath"),
            arguments.indices.contains(arguments.index(after: flagIndex))
        {
            return URL(fileURLWithPath: arguments[arguments.index(after: flagIndex)])
        }

        return nil
    }

    private static func songInfo(from exportedSong: PhysicalLibraryExportSong, exportDirectory: URL) -> SongInfo? {
        guard let id = UInt64(exportedSong.persistentID) ?? UInt64(exportedSong.persistentIDHex, radix: 16) else {
            return nil
        }

        return SongInfo(
            id: id,
            title: exportedSong.title,
            artist: exportedSong.artist,
            album: exportedSong.album,
            playCount: exportedSong.playCount,
            hasAssetURL: exportedSong.hasLocalAsset,
            mediaType: exportedSong.mediaType,
            duration: exportedSong.duration,
            artworkImage: artworkImage(for: exportedSong, exportDirectory: exportDirectory)
        )
    }

    private static func artworkImage(for exportedSong: PhysicalLibraryExportSong, exportDirectory: URL) -> UIImage? {
        guard let artworkPath = exportedSong.artworkPath else {
            return nil
        }

        let artworkURL = exportDirectory.appendingPathComponent(artworkPath)
        guard let data = try? Data(contentsOf: artworkURL) else {
            return nil
        }

        return UIImage(data: data)
    }
}
#endif
