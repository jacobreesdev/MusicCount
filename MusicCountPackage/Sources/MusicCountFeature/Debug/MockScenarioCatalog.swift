#if DEBUG
import Foundation
import UIKit

enum MockScenarioCatalog {
    static var librarySongs: [SongInfo] {
        librarySongs(artworkMap: [:], includingPreviewEdgeCases: true)
    }

    static func librarySongs(
        artworkMap: [String: UIImage?],
        includingPreviewEdgeCases: Bool
    ) -> [SongInfo] {
        let baseSongs = MockSongData.songs.enumerated().map { index, mockSong in
            makeSong(
                id: UInt64(index),
                title: mockSong.title,
                artist: mockSong.artist,
                album: mockSong.album,
                playCount: mockSong.playCount,
                duration: mockSong.duration,
                artworkImage: artworkMap[artworkKey(artist: mockSong.artist, album: mockSong.album)] ?? nil
            )
        }

        guard includingPreviewEdgeCases else { return baseSongs }
        return baseSongs + previewEdgeCaseSongs
    }

    static var activeRepairs: [ActiveRepair] {
        [
            ActiveRepair(
                id: "blinding lights-the weeknd",
                suggestionTitle: "Blinding Lights",
                suggestionArtist: "The Weeknd",
                canonicalSong: song(id: 0),
                retiredSongs: [
                    song(id: 1),
                    song(id: 2),
                ],
                repairAmount: song(id: 1).playCount + song(id: 2).playCount
            ),
            ActiveRepair(
                id: "shake it off-taylor swift",
                suggestionTitle: "Shake It Off",
                suggestionArtist: "Taylor Swift",
                canonicalSong: song(id: 4),
                retiredSongs: [
                    song(id: 7),
                ],
                repairAmount: song(id: 7).playCount
            ),
        ]
    }

    static var completedRepair: CompletedRepair {
        CompletedRepair(activeRepair: activeRepairs[0])
    }

    private static var previewEdgeCaseSongs: [SongInfo] {
        [
            makeSong(
                id: 10_001,
                title: "hate that i made you love me",
                artist: "Ari Example",
                album: "hate that i made you love me - Single",
                playCount: 144,
                duration: 212
            ),
            makeSong(
                id: 10_002,
                title: "hate that i made you love me (live from rehearsal)",
                artist: "Ari Example",
                album: "hate that i made you love me (live from rehearsal) - Single",
                playCount: 54,
                duration: 219
            ),
            makeSong(
                id: 10_003,
                title: "hate that i made you love me (ari lyric draft from bed)",
                artist: "Ari Example",
                album: "hate that i made you love me (ari lyric draft from bed) - Single",
                playCount: 11,
                duration: 225
            ),
            makeSong(
                id: 10_004,
                title: "Quiet Room",
                artist: "Zero Count Artist",
                album: "Unplayed Demos",
                playCount: 0,
                duration: 183
            ),
            makeSong(
                id: 10_005,
                title: "Quiet Room",
                artist: "Zero Count Artist",
                album: "Unplayed Sessions",
                playCount: 0,
                duration: 184
            ),
            makeSong(
                id: 10_006,
                title: "Run It Back",
                artist: "Big Gap Band",
                album: "Daily Rotation",
                playCount: 9_876,
                duration: 245
            ),
            makeSong(
                id: 10_007,
                title: "Run It Back",
                artist: "Big Gap Band",
                album: "First Upload",
                playCount: 1_234,
                duration: 245
            ),
            makeSong(
                id: 10_008,
                title: "Run It Back",
                artist: "Big Gap Band",
                album: "Live Cut",
                playCount: 987,
                duration: 252
            ),
        ]
    }

    private static func song(id: UInt64) -> SongInfo {
        guard let song = librarySongs.first(where: { $0.id == id }) else {
            preconditionFailure("Missing mock Library Song with id \(id).")
        }

        return song
    }

    private static func makeSong(
        id: UInt64,
        title: String,
        artist: String,
        album: String,
        playCount: Int,
        duration: TimeInterval,
        artworkImage: UIImage? = nil
    ) -> SongInfo {
        SongInfo(
            id: id,
            title: title,
            artist: artist,
            album: album,
            playCount: playCount,
            hasAssetURL: true,
            mediaType: "Music",
            duration: duration,
            artworkImage: artworkImage
        )
    }

    private static func artworkKey(artist: String, album: String) -> String {
        "\(artist)|\(album)"
    }
}
#endif
