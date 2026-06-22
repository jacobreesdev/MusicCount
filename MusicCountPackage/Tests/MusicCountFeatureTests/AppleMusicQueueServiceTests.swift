#if DEBUG
import Foundation
import Testing
@testable import MusicCountFeature

@MainActor
struct AppleMusicQueueServiceTests {
    @Test("Queue service uses injected client with default insert-next behavior", .bug(id: 23))
    func injectedClientReceivesDefaultQueueBehavior() throws {
        let isolatedDefaults = makeIsolatedUserDefaults()
        defer { isolatedDefaults.cleanUp() }
        let client = RecordingAppleMusicQueueClient()
        let service = AppleMusicQueueService(
            queueClient: client,
            userDefaults: isolatedDefaults.userDefaults
        )
        let song = SongInfo.testSong(id: 42)

        try service.addToQueue(song: song, count: 12)

        #expect(client.requests == [
            .init(songID: song.id, count: 12, behavior: .insertNext),
        ])
    }

    @Test("Queue service forwards persisted queue behavior to injected client", .bug(id: 23))
    func injectedClientReceivesPersistedQueueBehavior() throws {
        let isolatedDefaults = makeIsolatedUserDefaults()
        defer { isolatedDefaults.cleanUp() }
        let userDefaults = isolatedDefaults.userDefaults
        userDefaults.set(QueueBehavior.replaceQueue.rawValue, forKey: StorageKeys.queueBehavior)
        let client = RecordingAppleMusicQueueClient()
        let service = AppleMusicQueueService(queueClient: client, userDefaults: userDefaults)
        let song = SongInfo.testSong(id: 84)

        try service.addToQueue(song: song, count: 3)

        #expect(client.requests == [
            .init(songID: song.id, count: 3, behavior: .replaceQueue),
        ])
    }

    private func makeIsolatedUserDefaults() -> IsolatedUserDefaults {
        let suiteName = "MusicCountQueueServiceTests-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create isolated UserDefaults suite.")
        }
        userDefaults.removePersistentDomain(forName: suiteName)
        return IsolatedUserDefaults(userDefaults: userDefaults, suiteName: suiteName)
    }
}

private struct IsolatedUserDefaults {
    let userDefaults: UserDefaults
    let suiteName: String

    func cleanUp() {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
}

private struct AppleMusicQueueRequest: Equatable {
    let songID: UInt64
    let count: Int
    let behavior: QueueBehavior
}

@MainActor
private final class RecordingAppleMusicQueueClient: AppleMusicQueueClient {
    private(set) var requests: [AppleMusicQueueRequest] = []

    func addToQueue(song: SongInfo, count: Int, behavior: QueueBehavior) throws {
        requests.append(
            AppleMusicQueueRequest(
                songID: song.id,
                count: count,
                behavior: behavior
            )
        )
    }
}

private extension SongInfo {
    static func testSong(id: UInt64) -> SongInfo {
        SongInfo(
            id: id,
            title: "Preview Safe",
            artist: "Test Artist",
            album: "Test Album",
            playCount: 10,
            hasAssetURL: true,
            mediaType: "Music",
            duration: 180
        )
    }
}
#endif
