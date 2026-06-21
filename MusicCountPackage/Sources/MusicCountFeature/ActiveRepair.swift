import Foundation

/// A Suggestion whose Repair Queue has been built and still needs user follow-through.
struct ActiveRepair: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let suggestionTitle: String
    let suggestionArtist: String
    let canonicalSong: SongInfo
    let retiredSongs: [SongInfo]
    let repairAmount: Int

    init(
        id: String,
        suggestionTitle: String,
        suggestionArtist: String,
        canonicalSong: SongInfo,
        retiredSongs: [SongInfo],
        repairAmount: Int
    ) {
        self.id = id
        self.suggestionTitle = suggestionTitle
        self.suggestionArtist = suggestionArtist
        self.canonicalSong = canonicalSong
        self.retiredSongs = retiredSongs
        self.repairAmount = repairAmount
    }
}

enum ActiveRepairError: Error, Equatable, Sendable {
    case alreadyExists
}
