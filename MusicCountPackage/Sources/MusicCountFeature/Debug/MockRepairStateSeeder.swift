#if DEBUG
import Foundation

enum MockRepairStateSeeder {
    static func seedActiveRepairsIfRequested() {
        resetRepairStateIfRequested()

        guard ProcessInfo.processInfo.arguments.contains("-MockActiveRepairs") else { return }

        let activeRepairs = [
            ActiveRepair(
                id: "blinding lights-the weeknd",
                suggestionTitle: "Blinding Lights",
                suggestionArtist: "The Weeknd",
                canonicalSong: makeSong(
                    id: 0,
                    title: "Blinding Lights",
                    artist: "The Weeknd",
                    album: "After Hours",
                    playCount: 612
                ),
                retiredSongs: [
                    makeSong(
                        id: 1,
                        title: "Blinding Lights",
                        artist: "The Weeknd",
                        album: "The Highlights",
                        playCount: 345
                    ),
                    makeSong(
                        id: 2,
                        title: "Blinding Lights",
                        artist: "The Weeknd",
                        album: "Live At SoFi Stadium",
                        playCount: 178
                    ),
                ],
                repairAmount: 523
            ),
            ActiveRepair(
                id: "shake it off-taylor swift",
                suggestionTitle: "Shake It Off",
                suggestionArtist: "Taylor Swift",
                canonicalSong: makeSong(
                    id: 4,
                    title: "Shake It Off",
                    artist: "Taylor Swift",
                    album: "1989 (Deluxe)",
                    playCount: 287
                ),
                retiredSongs: [
                    makeSong(
                        id: 7,
                        title: "Shake It Off",
                        artist: "Taylor Swift",
                        album: "Pop Hits 2014",
                        playCount: 67
                    ),
                ],
                repairAmount: 67
            ),
        ]

        do {
            let data = try JSONEncoder().encode(activeRepairs)
            UserDefaults.standard.set(data, forKey: StorageKeys.activeRepairs)
        } catch {
            UserDefaults.standard.removeObject(forKey: StorageKeys.activeRepairs)
        }
    }

    private static func resetRepairStateIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ResetRepairState") || arguments.contains("-MockActiveRepairs") else { return }

        UserDefaults.standard.removeObject(forKey: StorageKeys.dismissedSuggestions)
        UserDefaults.standard.removeObject(forKey: StorageKeys.activeRepairs)
        UserDefaults.standard.removeObject(forKey: StorageKeys.completedRepairs)
        UserDefaults.standard.removeObject(forKey: StorageKeys.songsToRemovePlaylistID)
    }

    private static func makeSong(
        id: UInt64,
        title: String,
        artist: String,
        album: String,
        playCount: Int
    ) -> SongInfo {
        SongInfo(
            id: id,
            title: title,
            artist: artist,
            album: album,
            playCount: playCount,
            hasAssetURL: true,
            mediaType: "Music",
            duration: 200
        )
    }
}
#endif
