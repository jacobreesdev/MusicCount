import Foundation

/// Presentation state for repairing one Suggestion.
struct SuggestionRepairModel: Equatable, Sendable {
    let suggestion: Suggestion
    private(set) var canonicalSongID: UInt64
    private(set) var excludedSongIDs: Set<UInt64>
    private(set) var decision: RepairDecision

    var songs: [SongInfo] {
        suggestion.songs
    }

    var canonicalSong: SongInfo {
        decision.canonicalSong
    }

    var retiredSongs: [SongInfo] {
        decision.retiredSongs
    }

    var excludedSongs: [SongInfo] {
        decision.excludedSongs
    }

    var repairAmount: Int {
        decision.repairAmount
    }

    var canBuildRepairQueue: Bool {
        decision.requiresRepairQueue
    }

    init(suggestion: Suggestion) throws {
        let defaultCanonicalSong = suggestion.highestPlayCount
        let decision = try RepairDecision(
            duplicateGroup: suggestion.songs,
            canonicalSongID: defaultCanonicalSong.id
        )

        self.suggestion = suggestion
        self.canonicalSongID = defaultCanonicalSong.id
        self.excludedSongIDs = []
        self.decision = decision
    }

    mutating func chooseCanonicalSong(id songID: UInt64) throws {
        let previousCanonicalSongID = canonicalSongID
        let previousDecision = decision
        canonicalSongID = songID
        excludedSongIDs.remove(songID)

        do {
            decision = try RepairDecision(
                duplicateGroup: songs,
                canonicalSongID: canonicalSongID,
                excludedSongIDs: excludedSongIDs
            )
        } catch {
            canonicalSongID = previousCanonicalSongID
            decision = previousDecision
            throw error
        }
    }

    mutating func setIncludedAsRetired(_ isIncluded: Bool, forSongID songID: UInt64) throws {
        guard songID != canonicalSongID else {
            throw RepairDecisionError.canonicalSongCannotBeExcluded
        }

        let previousExcludedSongIDs = excludedSongIDs
        let previousDecision = decision

        if isIncluded {
            excludedSongIDs.remove(songID)
        } else {
            excludedSongIDs.insert(songID)
        }

        do {
            decision = try RepairDecision(
                duplicateGroup: songs,
                canonicalSongID: canonicalSongID,
                excludedSongIDs: excludedSongIDs
            )
        } catch {
            excludedSongIDs = previousExcludedSongIDs
            decision = previousDecision
            throw error
        }
    }

    func role(for song: SongInfo) -> SuggestionRepairSongRole {
        if song.id == canonicalSongID {
            return .canonical
        }

        if excludedSongIDs.contains(song.id) {
            return .excluded
        }

        return .retired
    }

    func isIncludedAsRetired(songID: UInt64) -> Bool {
        songID != canonicalSongID && excludedSongIDs.contains(songID) == false
    }
}

enum SuggestionRepairSongRole: Equatable, Sendable {
    case canonical
    case retired
    case excluded
}
