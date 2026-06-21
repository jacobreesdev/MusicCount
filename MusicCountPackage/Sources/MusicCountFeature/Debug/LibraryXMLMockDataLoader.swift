#if DEBUG
import Foundation

enum LibraryXMLMockDataLoader {
    static func loadSongs() -> [SongInfo]? {
        guard let url = libraryURL() else { return nil }

        do {
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.xml
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
            guard
                let root = plist as? [String: Any],
                let tracks = root["Tracks"] as? [String: Any]
            else {
                return nil
            }

            let songs = tracks
                .compactMap { trackID, value -> (Int, SongInfo)? in
                    guard
                        let exportedTrackID = Int(trackID),
                        let track = value as? [String: Any],
                        let song = songInfo(from: track, fallbackID: UInt64(exportedTrackID))
                    else {
                        return nil
                    }

                    return (exportedTrackID, song)
                }
                .sorted { $0.0 < $1.0 }
                .map(\.1)

            return songs.isEmpty ? nil : songs
        } catch {
            return nil
        }
    }

    private static func libraryURL() -> URL? {
        Bundle.module.url(forResource: "Library", withExtension: "xml", subdirectory: "Debug/Fixtures") ??
            Bundle.module.url(forResource: "Library", withExtension: "xml")
    }

    private static func songInfo(from track: [String: Any], fallbackID: UInt64) -> SongInfo? {
        guard
            let title = track["Name"] as? String,
            let artist = track["Artist"] as? String
        else {
            return nil
        }

        let album = track["Album"] as? String ?? "Unknown Album"
        let playCount = track["Play Count"] as? Int ?? 0
        let totalTimeMilliseconds = track["Total Time"] as? Int ?? 0
        let persistentID = (track["Persistent ID"] as? String)
            .flatMap { UInt64($0, radix: 16) } ?? fallbackID
        let trackType = track["Track Type"] as? String

        return SongInfo(
            id: persistentID,
            title: title,
            artist: artist,
            album: album,
            playCount: playCount,
            hasAssetURL: trackType == "File",
            mediaType: mediaTypeDescription(from: track),
            duration: TimeInterval(totalTimeMilliseconds) / 1_000
        )
    }

    private static func mediaTypeDescription(from track: [String: Any]) -> String {
        if let mediaKind = track["Media Kind"] as? String {
            return mediaKind
        }

        if let kind = track["Kind"] as? String, kind.localizedCaseInsensitiveContains("audio") {
            return "Music"
        }

        return "Unknown"
    }
}
#endif
