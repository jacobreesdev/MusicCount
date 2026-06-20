import Foundation

/// A user's repair decision for a Duplicate Group.
struct RepairDecision: Equatable, Sendable {
    let duplicateGroup: [SongInfo]
    let canonicalSong: SongInfo
    let retiredSongs: [SongInfo]
    let excludedSongs: [SongInfo]

    init(
        duplicateGroup: [SongInfo],
        canonicalSongID: UInt64?,
        excludedSongIDs: Set<UInt64> = []
    ) throws {
        let songIDs = Set(duplicateGroup.map(\.id))
        let defaultRetiredSongIDs = canonicalSongID.map { canonicalSongID in
            songIDs
                .subtracting([canonicalSongID])
                .subtracting(excludedSongIDs)
        } ?? []

        try self.init(
            duplicateGroup: duplicateGroup,
            canonicalSongID: canonicalSongID,
            retiredSongIDs: defaultRetiredSongIDs,
            excludedSongIDs: excludedSongIDs
        )
    }

    init(
        duplicateGroup: [SongInfo],
        canonicalSongID: UInt64?,
        retiredSongIDs: Set<UInt64>,
        excludedSongIDs: Set<UInt64> = []
    ) throws {
        guard duplicateGroup.count >= 2 else {
            throw RepairDecisionError.duplicateGroupRequiresAtLeastTwoSongs
        }

        guard let canonicalSongID else {
            throw RepairDecisionError.missingCanonicalSong
        }

        guard let canonicalSong = duplicateGroup.first(where: { $0.id == canonicalSongID }) else {
            throw RepairDecisionError.canonicalSongNotInDuplicateGroup
        }

        guard retiredSongIDs.contains(canonicalSongID) == false else {
            throw RepairDecisionError.canonicalSongCannotBeRetired
        }

        guard excludedSongIDs.contains(canonicalSongID) == false else {
            throw RepairDecisionError.canonicalSongCannotBeExcluded
        }

        let songIDs = Set(duplicateGroup.map(\.id))
        let expectedRetiredSongIDs = songIDs
            .subtracting([canonicalSongID])
            .subtracting(excludedSongIDs)

        guard retiredSongIDs == expectedRetiredSongIDs else {
            throw RepairDecisionError.includedSongMustBeRetired
        }

        guard retiredSongIDs.isEmpty == false else {
            throw RepairDecisionError.requiresAtLeastOneRetiredSong
        }

        self.duplicateGroup = duplicateGroup
        self.canonicalSong = canonicalSong
        self.retiredSongs = duplicateGroup.filter { retiredSongIDs.contains($0.id) }
        self.excludedSongs = duplicateGroup.filter { song in
            excludedSongIDs.contains(song.id)
        }
    }
}

enum RepairDecisionError: Error, Equatable, Sendable {
    case duplicateGroupRequiresAtLeastTwoSongs
    case missingCanonicalSong
    case canonicalSongNotInDuplicateGroup
    case canonicalSongCannotBeRetired
    case canonicalSongCannotBeExcluded
    case includedSongMustBeRetired
    case requiresAtLeastOneRetiredSong
}
