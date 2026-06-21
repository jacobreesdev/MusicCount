import Foundation
import Testing
@testable import MusicCountFeature

@Suite("LibraryXMLMockDataLoader Tests")
struct LibraryXMLMockDataLoaderTests {
    @Test("Loads the full Library.xml export for mock data", .bug(id: 15))
    func loadsFullLibraryXMLExport() throws {
        let songs = try #require(LibraryXMLMockDataLoader.loadSongs())

        #expect(songs.count > 1_000)
        #expect(songs.contains { $0.title == "New York" && $0.artist == "Addison Rae" })
        #expect(songs.contains { $0.id == 12_735_721_974_494_978_572 && $0.title == "begged (Saturday Night Live 2026)" })
        #expect(songs.contains { $0.id == 15_896_030_370_299_071_748 && $0.title == "begged" })
    }
}
