#if DEBUG
import Testing
@testable import MusicCountFeature

@MainActor
struct PreviewScenarioCatalogTests {
    @Test("Preview scenario data covers issue 23 repair surfaces", .bug(id: 23))
    func previewScenarioDataCoversRepairSurfaces() {
        let suggestions = MusicCountPreviewData.populatedSuggestions
        let alternateCanonicalModel = MusicCountPreviewData.alternateCanonicalModel()
        let excludedRetiredSongModel = MusicCountPreviewData.excludedRetiredSongModel()

        #expect(suggestions.contains { $0.songs.count == 2 })
        #expect(suggestions.contains { $0.songs.count > 2 })
        #expect(suggestions.contains { $0.playCountDifference >= 8_000 })
        #expect(MusicCountPreviewData.longLibrarySong.title.contains("ari lyric draft from bed"))
        #expect(MusicCountPreviewData.zeroPlayCountsSuggestion.songs.allSatisfy { $0.playCount == 0 })
        #expect(alternateCanonicalModel.canonicalSong.id == 3)
        #expect(excludedRetiredSongModel.excludedSongs.map(\.id) == [10_003])
    }

    @Test("Preview Library Songs derive from MockSongData", .bug(id: 23))
    func previewLibrarySongsDeriveFromMockSongData() throws {
        let songs = MusicCountPreviewData.librarySongs
        let firstMockSong = try #require(MockSongData.songs.first)
        let firstPreviewSong = try #require(songs.first)

        #expect(songs.count >= MockSongData.songs.count)
        #expect(firstPreviewSong.title == firstMockSong.title)
        #expect(firstPreviewSong.artist == firstMockSong.artist)
        #expect(firstPreviewSong.album == firstMockSong.album)
        #expect(firstPreviewSong.playCount == firstMockSong.playCount)
        #expect(songs.contains { $0.title.contains("ari lyric draft from bed") })
    }

    @Test("Active Repair previews reuse mock active repair seed data", .bug(id: 23))
    func activeRepairPreviewsReuseMockActiveRepairSeedData() {
        let activeRepairs = MusicCountPreviewData.activeRepairs
        let librarySongIDs = Set(MusicCountPreviewData.librarySongs.map(\.id))
        let repairSongIDs = activeRepairs.flatMap { repair in
            [repair.canonicalSong.id] + repair.retiredSongs.map(\.id)
        }

        #expect(activeRepairs.map(\.id) == [
            "blinding lights-the weeknd",
            "shake it off-taylor swift",
        ])
        #expect(repairSongIDs.allSatisfy { librarySongIDs.contains($0) })
        #expect(activeRepairs.allSatisfy { repair in
            repair.repairAmount == repair.retiredSongs.reduce(0) { $0 + $1.playCount }
        })
    }
}
#endif
