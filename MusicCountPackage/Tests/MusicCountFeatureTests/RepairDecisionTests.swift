import Foundation
import Testing
@testable import MusicCountFeature

/// Tests for the repair decision a user makes for a Duplicate Group.
@Suite("RepairDecision Tests")
struct RepairDecisionTests {

    // MARK: - Test Fixtures

    private func makeSong(id: UInt64, playCount: Int) -> SongInfo {
        SongInfo(
            id: id,
            title: "Test Song",
            artist: "Test Artist",
            album: "Test Album",
            playCount: playCount,
            hasAssetURL: true,
            mediaType: "Music",
            duration: 200
        )
    }

    // MARK: - Canonical and Retired Songs

    @Test("Represents a Duplicate Group with one Canonical Song and one default Retired Song")
    func representsCanonicalSongAndDefaultRetiredSong() throws {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let lowerPlayCountSong = makeSong(id: 2, playCount: 20)

        let decision = try RepairDecision(
            duplicateGroup: [canonicalSong, lowerPlayCountSong],
            canonicalSongID: canonicalSong.id
        )

        #expect(decision.canonicalSong == canonicalSong)
        #expect(decision.retiredSongs == [lowerPlayCountSong])
        #expect(decision.excludedSongs.isEmpty)
    }

    @Test("Excludes a distinct Library Song from Retired Songs")
    func excludesDistinctLibrarySongFromRetiredSongs() throws {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let retiredSong = makeSong(id: 2, playCount: 20)
        let distinctSong = makeSong(id: 3, playCount: 5)

        let decision = try RepairDecision(
            duplicateGroup: [canonicalSong, retiredSong, distinctSong],
            canonicalSongID: canonicalSong.id,
            excludedSongIDs: [distinctSong.id]
        )

        #expect(decision.canonicalSong == canonicalSong)
        #expect(decision.retiredSongs == [retiredSong])
        #expect(decision.excludedSongs == [distinctSong])
    }

    // MARK: - Repair Amount

    @Test("Repair Amount sums included Retired Song play counts")
    func repairAmountSumsIncludedRetiredSongPlayCounts() throws {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let retiredSong = makeSong(id: 2, playCount: 20)

        let decision = try RepairDecision(
            duplicateGroup: [canonicalSong, retiredSong],
            canonicalSongID: canonicalSong.id
        )

        #expect(decision.repairAmount == 20)
    }

    @Test("Repair Amount sums multiple Retired Songs")
    func repairAmountSumsMultipleRetiredSongs() throws {
        let canonicalSong = makeSong(id: 1, playCount: 100)
        let firstRetiredSong = makeSong(id: 2, playCount: 30)
        let secondRetiredSong = makeSong(id: 3, playCount: 45)
        let zeroPlayRetiredSong = makeSong(id: 4, playCount: 0)

        let decision = try RepairDecision(
            duplicateGroup: [canonicalSong, firstRetiredSong, secondRetiredSong, zeroPlayRetiredSong],
            canonicalSongID: canonicalSong.id
        )

        #expect(decision.repairAmount == 75)
        #expect(decision.requiresRepairQueue)
    }

    @Test("Repair Amount ignores Canonical Song and excluded Library Songs")
    func repairAmountIgnoresCanonicalSongAndExcludedSongs() throws {
        let canonicalSong = makeSong(id: 1, playCount: 100)
        let retiredSong = makeSong(id: 2, playCount: 30)
        let excludedSong = makeSong(id: 3, playCount: 70)

        let decision = try RepairDecision(
            duplicateGroup: [canonicalSong, retiredSong, excludedSong],
            canonicalSongID: canonicalSong.id,
            excludedSongIDs: [excludedSong.id]
        )

        #expect(decision.repairAmount == 30)
        #expect(decision.requiresRepairQueue)
    }

    @Test("Zero Repair Amount does not require a Repair Queue")
    func zeroRepairAmountDoesNotRequireRepairQueue() throws {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let zeroPlayRetiredSong = makeSong(id: 2, playCount: 0)

        let decision = try RepairDecision(
            duplicateGroup: [canonicalSong, zeroPlayRetiredSong],
            canonicalSongID: canonicalSong.id
        )

        #expect(decision.repairAmount == 0)
        #expect(decision.requiresRepairQueue == false)
    }

    // MARK: - Validation

    @Test("Rejects a repair decision without a Canonical Song")
    func rejectsMissingCanonicalSong() {
        let songs = [
            makeSong(id: 1, playCount: 50),
            makeSong(id: 2, playCount: 20),
        ]

        #expect(throws: RepairDecisionError.missingCanonicalSong) {
            try RepairDecision(duplicateGroup: songs, canonicalSongID: nil)
        }
    }

    @Test("Rejects a Duplicate Group with fewer than two Library Songs")
    func rejectsDuplicateGroupWithFewerThanTwoSongs() {
        let onlySong = makeSong(id: 1, playCount: 50)

        #expect(throws: RepairDecisionError.duplicateGroupRequiresAtLeastTwoSongs) {
            try RepairDecision(duplicateGroup: [onlySong], canonicalSongID: onlySong.id)
        }
    }

    @Test("Rejects a Canonical Song also listed as a Retired Song")
    func rejectsCanonicalSongAlsoListedAsRetired() {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let lowerPlayCountSong = makeSong(id: 2, playCount: 20)

        #expect(throws: RepairDecisionError.canonicalSongCannotBeRetired) {
            try RepairDecision(
                duplicateGroup: [canonicalSong, lowerPlayCountSong],
                canonicalSongID: canonicalSong.id,
                retiredSongIDs: [canonicalSong.id]
            )
        }
    }

    @Test("Rejects a Canonical Song also listed as an excluded Library Song")
    func rejectsCanonicalSongAlsoListedAsExcluded() {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let lowerPlayCountSong = makeSong(id: 2, playCount: 20)

        #expect(throws: RepairDecisionError.canonicalSongCannotBeExcluded) {
            try RepairDecision(
                duplicateGroup: [canonicalSong, lowerPlayCountSong],
                canonicalSongID: canonicalSong.id,
                excludedSongIDs: [canonicalSong.id]
            )
        }
    }

    @Test("Rejects a Retired Song outside the Duplicate Group")
    func rejectsRetiredSongOutsideDuplicateGroup() {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let lowerPlayCountSong = makeSong(id: 2, playCount: 20)

        #expect(throws: RepairDecisionError.retiredSongNotInDuplicateGroup) {
            try RepairDecision(
                duplicateGroup: [canonicalSong, lowerPlayCountSong],
                canonicalSongID: canonicalSong.id,
                retiredSongIDs: [lowerPlayCountSong.id, 999]
            )
        }
    }

    @Test("Rejects an excluded Library Song outside the Duplicate Group")
    func rejectsExcludedSongOutsideDuplicateGroup() {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let lowerPlayCountSong = makeSong(id: 2, playCount: 20)

        #expect(throws: RepairDecisionError.excludedSongNotInDuplicateGroup) {
            try RepairDecision(
                duplicateGroup: [canonicalSong, lowerPlayCountSong],
                canonicalSongID: canonicalSong.id,
                excludedSongIDs: [999]
            )
        }
    }

    @Test("Rejects an included non-canonical Library Song that is not retired")
    func rejectsIncludedSongMissingFromRetiredSongs() {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let includedSong = makeSong(id: 2, playCount: 20)
        let excludedSong = makeSong(id: 3, playCount: 5)

        #expect(throws: RepairDecisionError.includedSongMustBeRetired) {
            try RepairDecision(
                duplicateGroup: [canonicalSong, includedSong, excludedSong],
                canonicalSongID: canonicalSong.id,
                retiredSongIDs: [],
                excludedSongIDs: [excludedSong.id]
            )
        }
    }

    @Test("Rejects a repair decision with no Retired Songs")
    func rejectsDecisionWithNoRetiredSongs() {
        let canonicalSong = makeSong(id: 1, playCount: 50)
        let distinctSong = makeSong(id: 2, playCount: 5)

        #expect(throws: RepairDecisionError.requiresAtLeastOneRetiredSong) {
            try RepairDecision(
                duplicateGroup: [canonicalSong, distinctSong],
                canonicalSongID: canonicalSong.id,
                excludedSongIDs: [distinctSong.id]
            )
        }
    }
}
