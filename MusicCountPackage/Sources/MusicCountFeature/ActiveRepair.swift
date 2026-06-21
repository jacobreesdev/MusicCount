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

/// A repair the user has marked done after follow-through outside MusicCount.
struct CompletedRepair: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let suggestionTitle: String
    let suggestionArtist: String
    let canonicalSong: SongInfo
    let retiredSongs: [SongInfo]
    let repairAmount: Int

    init(activeRepair: ActiveRepair) {
        id = activeRepair.id
        suggestionTitle = activeRepair.suggestionTitle
        suggestionArtist = activeRepair.suggestionArtist
        canonicalSong = activeRepair.canonicalSong
        retiredSongs = activeRepair.retiredSongs
        repairAmount = activeRepair.repairAmount
    }
}

enum ActiveRepairError: Error, Equatable, LocalizedError, Sendable {
    case alreadyExists
    case notFound

    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            return "This Suggestion already has an Active Repair."
        case .notFound:
            return "MusicCount could not find this Active Repair."
        }
    }
}
