import Foundation
import Testing
@testable import MusicCountFeature

/// Tests for the repair-flow state shown when opening a Suggestion.
struct SuggestionRepairModelTests {

    private func makeSong(id: UInt64, album: String, playCount: Int) -> SongInfo {
        SongInfo(
            id: id,
            title: "Midnight City",
            artist: "M83",
            album: album,
            playCount: playCount,
            hasAssetURL: true,
            mediaType: "Music",
            duration: 244
        )
    }

    private func makeSuggestion() -> Suggestion {
        Suggestion(
            sharedTitle: "Midnight City",
            sharedArtist: "M83",
            songs: [
                makeSong(id: 1, album: "Hurry Up, We're Dreaming", playCount: 140),
                makeSong(id: 2, album: "Alternative Hits", playCount: 22),
                makeSong(id: 3, album: "Live Session", playCount: 8),
            ]
        )
    }

    @Test("Opening a Suggestion prepares all Library Songs for repair review")
    func preparesAllLibrarySongsForRepairReview() throws {
        let suggestion = makeSuggestion()
        let model = try SuggestionRepairModel(suggestion: suggestion)

        #expect(model.songs.map(\.id) == [1, 2, 3])
        #expect(model.canonicalSong.id == 1)
        #expect(model.retiredSongs.map(\.id) == [2, 3])
        #expect(model.excludedSongs.isEmpty)
        #expect(model.repairAmount == 30)
        #expect(model.canBuildRepairQueue)
    }

    @Test("Choosing a different Canonical Song updates Retired Songs and Repair Amount")
    func choosingCanonicalSongUpdatesRepairDecision() throws {
        let suggestion = makeSuggestion()
        var model = try SuggestionRepairModel(suggestion: suggestion)

        try model.chooseCanonicalSong(id: 2)

        #expect(model.canonicalSong.id == 2)
        #expect(model.retiredSongs.map(\.id) == [1, 3])
        #expect(model.repairAmount == 148)
    }

    @Test("Excluding a distinct Library Song removes it from Retired Songs")
    func excludingDistinctLibrarySongRemovesItFromRetiredSongs() throws {
        let suggestion = makeSuggestion()
        var model = try SuggestionRepairModel(suggestion: suggestion)

        try model.setIncludedAsRetired(false, forSongID: 3)

        #expect(model.retiredSongs.map(\.id) == [2])
        #expect(model.excludedSongs.map(\.id) == [3])
        #expect(model.repairAmount == 22)
    }
}
