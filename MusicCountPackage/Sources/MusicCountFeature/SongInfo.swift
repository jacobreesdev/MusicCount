import Foundation
import UIKit

/// Song metadata from the user's Apple Music library.
///
/// Uses `@unchecked Sendable` because UIImage isn't formally Sendable,
/// but artwork is immutable after creation and only read across boundaries.
struct SongInfo: Identifiable, Equatable, @unchecked Sendable {
    let id: UInt64
    let title: String
    let artist: String
    let album: String
    let playCount: Int
    let hasAssetURL: Bool
    let mediaType: String
    let duration: TimeInterval
    let artworkImage: UIImage?

    init(
        id: UInt64,
        title: String,
        artist: String,
        album: String,
        playCount: Int,
        hasAssetURL: Bool,
        mediaType: String,
        duration: TimeInterval,
        artworkImage: UIImage? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.playCount = playCount
        self.hasAssetURL = hasAssetURL
        self.mediaType = mediaType
        self.duration = duration
        self.artworkImage = artworkImage
    }

    /// Formatted duration string (M:SS or H:MM:SS)
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Formatted duration for accessibility (e.g., "3 minutes 45 seconds")
    var accessibleDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        var components: [String] = []

        if hours > 0 {
            components.append("\(hours) \(hours == 1 ? "hour" : "hours")")
        }
        if minutes > 0 {
            components.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
        }
        if seconds > 0 || components.isEmpty {
            components.append("\(seconds) \(seconds == 1 ? "second" : "seconds")")
        }

        return components.joined(separator: " ")
    }

    /// Whether artwork is available
    var hasArtwork: Bool {
        artworkImage != nil
    }
}

extension SongInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case album
        case playCount
        case hasAssetURL
        case mediaType
        case duration
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UInt64.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            artist: try container.decode(String.self, forKey: .artist),
            album: try container.decode(String.self, forKey: .album),
            playCount: try container.decode(Int.self, forKey: .playCount),
            hasAssetURL: try container.decode(Bool.self, forKey: .hasAssetURL),
            mediaType: try container.decode(String.self, forKey: .mediaType),
            duration: try container.decode(TimeInterval.self, forKey: .duration),
            artworkImage: nil
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encode(album, forKey: .album)
        try container.encode(playCount, forKey: .playCount)
        try container.encode(hasAssetURL, forKey: .hasAssetURL)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encode(duration, forKey: .duration)
    }
}

/// Aggregate statistics for a collection of songs.
struct LibraryStats: Sendable {
    let totalSongs: Int
    let songsWithPlayCounts: Int
    let songsWithLocalAssets: Int
    let averagePlayCount: Double

    init(songs: [SongInfo]) {
        self.totalSongs = songs.count
        self.songsWithPlayCounts = songs.filter { $0.playCount > 0 }.count
        self.songsWithLocalAssets = songs.filter { $0.hasAssetURL }.count

        let totalPlays = songs.reduce(0) { $0 + $1.playCount }
        self.averagePlayCount = songs.isEmpty ? 0 : Double(totalPlays) / Double(songs.count)
    }
}
