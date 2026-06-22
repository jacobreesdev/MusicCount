#if DEBUG
import Foundation
import MediaPlayer
import SwiftUI
import UIKit

public enum PhysicalLibraryExportLaunch {
    public static let argument = "ExportLibrarySongs"

    public static var isRequested: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(argument) || arguments.contains("-\(argument)")
    }

    public static var runID: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("ExportRunID=") }
            .map { String($0.dropFirst("ExportRunID=".count)) }
    }
}

public struct PhysicalLibraryExportView: View {
    @State private var status = "Preparing Library Song export..."
    @State private var didStart = false

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .task {
            guard didStart == false else { return }
            didStart = true
            await runExport()
        }
    }

    private func runExport() async {
        do {
            status = "Requesting Media Library access..."
            let summary = try await PhysicalLibraryExporter.export(runID: PhysicalLibraryExportLaunch.runID)
            status = "Exported \(summary.songCount) Library Songs."
            NSLog("MusicCountLibraryExport complete: \(summary.songCount) songs, \(summary.songsWithPlayCounts) with play counts, \(summary.songsWithArtwork) with artwork. Output: \(summary.relativeManifestPath)")
            exitSoon(with: EXIT_SUCCESS)
        } catch {
            status = "Library Song export failed."
            NSLog("MusicCountLibraryExport failed: \(error.localizedDescription)")
            exitSoon(with: EXIT_FAILURE)
        }
    }

    private func exitSoon(with code: Int32) {
        Task {
            try? await Task.sleep(for: .seconds(1))
            Darwin.exit(code)
        }
    }
}

enum PhysicalLibraryExporter {
    static let directoryName = "MusicCountLibraryExport"

    static func export(runID: String?) async throws -> PhysicalLibraryExportSummary {
        let exportDirectory = try prepareExportDirectory()
        try writeStatus(
            PhysicalLibraryExportStatus(
                runID: runID,
                state: "preparing",
                message: "Prepared export directory."
            ),
            to: exportDirectory
        )

        do {
            try writeStatus(
                PhysicalLibraryExportStatus(
                    runID: runID,
                    state: "waitingForAuthorization",
                    message: "Requesting or verifying Media Library access."
                ),
                to: exportDirectory
            )
            let authorizationStatus = await requestAuthorizationIfNeeded()
            try writeStatus(
                PhysicalLibraryExportStatus(
                    runID: runID,
                    state: authorizationStatus == .authorized ? "authorized" : "authorizationDenied",
                    message: "Media Library authorization status: \(authorizationStatus.exportDescription)."
                ),
                to: exportDirectory
            )
            guard authorizationStatus == .authorized else {
                throw PhysicalLibraryExportError.mediaLibraryPermissionDenied(status: authorizationStatus.exportDescription)
            }

            try writeStatus(
                PhysicalLibraryExportStatus(
                    runID: runID,
                    state: "scanningLibrary",
                    message: "Reading Library Songs and artwork from MPMediaQuery.songs()."
                ),
                to: exportDirectory
            )
            let exportedSongs = try await Task.detached(priority: .userInitiated) {
                try scanAuthorizedLibrary(
                    writingArtworkTo: exportDirectory.appendingPathComponent("artwork", isDirectory: true),
                    reportingStatusTo: exportDirectory,
                    runID: runID
                )
            }.value

            guard exportedSongs.isEmpty == false else {
                throw PhysicalLibraryExportError.noReadableLibrarySongs
            }

            try writeStatus(
                PhysicalLibraryExportStatus(
                    runID: runID,
                    state: "writingManifest",
                    message: "Writing deterministic manifest.json.",
                    songCount: exportedSongs.count,
                    songsWithPlayCounts: exportedSongs.filter { $0.playCount > 0 }.count,
                    songsWithArtwork: exportedSongs.filter(\.hasArtwork).count
                ),
                to: exportDirectory
            )
            let manifestData = try PhysicalLibraryExportManifestBuilder.makeManifestData(from: exportedSongs)
            let manifestURL = exportDirectory.appendingPathComponent("manifest.json")
            try manifestData.write(to: manifestURL, options: .atomic)

            let summary = PhysicalLibraryExportSummary(
                songCount: exportedSongs.count,
                songsWithPlayCounts: exportedSongs.filter { $0.playCount > 0 }.count,
                songsWithArtwork: exportedSongs.filter(\.hasArtwork).count,
                relativeManifestPath: "\(directoryName)/manifest.json"
            )

            try writeStatus(
                PhysicalLibraryExportStatus(
                    runID: runID,
                    state: "complete",
                    message: "Library Song export complete.",
                    songCount: summary.songCount,
                    songsWithPlayCounts: summary.songsWithPlayCounts,
                    songsWithArtwork: summary.songsWithArtwork,
                    relativeManifestPath: summary.relativeManifestPath
                ),
                to: exportDirectory
            )

            return summary
        } catch {
            try? writeStatus(
                PhysicalLibraryExportStatus(
                    runID: runID,
                    state: "failed",
                    message: error.localizedDescription
                ),
                to: exportDirectory
            )
            try? writeFailure(error, to: exportDirectory)
            throw error
        }
    }

    private static func requestAuthorizationIfNeeded() async -> MPMediaLibraryAuthorizationStatus {
        let currentStatus = MPMediaLibrary.authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func prepareExportDirectory() throws -> URL {
        let documentsDirectory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let exportDirectory = documentsDirectory.appendingPathComponent(directoryName, isDirectory: true)
        let artworkDirectory = exportDirectory.appendingPathComponent("artwork", isDirectory: true)

        if FileManager.default.fileExists(atPath: exportDirectory.path) {
            try FileManager.default.removeItem(at: exportDirectory)
        }

        try FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        return exportDirectory
    }

    private static func scanAuthorizedLibrary(
        writingArtworkTo artworkDirectory: URL,
        reportingStatusTo exportDirectory: URL,
        runID: String?
    ) throws -> [PhysicalLibraryExportSongInput] {
        let query = MPMediaQuery.songs()
        let items = (query.items ?? [])
            .filter { $0.persistentID != 0 }

        var songs: [PhysicalLibraryExportSongInput] = []
        songs.reserveCapacity(items.count)
        var songsWithPlayCounts = 0
        var songsWithArtwork = 0

        for (index, item) in items.enumerated() {
            try autoreleasepool {
                let persistentID = item.persistentID
                let hasArtwork = try exportArtwork(
                    from: item,
                    persistentID: persistentID,
                    artworkDirectory: artworkDirectory
                )

                if item.playCount > 0 {
                    songsWithPlayCounts += 1
                }

                if hasArtwork {
                    songsWithArtwork += 1
                }

                songs.append(PhysicalLibraryExportSongInput(
                    persistentID: persistentID,
                    title: item.title,
                    artist: item.artist,
                    album: item.albumTitle,
                    albumArtist: item.albumArtist,
                    genre: item.genre,
                    duration: item.playbackDuration,
                    playCount: item.playCount,
                    mediaType: mediaTypeDescription(item.mediaType),
                    hasLocalAsset: item.assetURL != nil,
                    isCloudItem: item.isCloudItem,
                    playbackStoreID: item.playbackStoreID,
                    hasArtwork: hasArtwork
                ))
            }

            if index == 0 || (index + 1).isMultiple(of: 100) || index + 1 == items.count {
                try writeStatus(
                    PhysicalLibraryExportStatus(
                        runID: runID,
                        state: "scanningLibrary",
                        message: "Scanned \(index + 1) of \(items.count) Library Songs.",
                        songCount: songs.count,
                        songsWithPlayCounts: songsWithPlayCounts,
                        songsWithArtwork: songsWithArtwork
                    ),
                    to: exportDirectory
                )
            }

            try Task.checkCancellation()
        }

        return songs
    }

    private static func exportArtwork(
        from item: MPMediaItem,
        persistentID: MPMediaEntityPersistentID,
        artworkDirectory: URL
    ) throws -> Bool {
        guard
            let image = item.artwork?.image(at: CGSize(width: 150, height: 150)),
            let imageData = image.pngData()
        else {
            return false
        }

        let filename = PhysicalLibraryExportManifestBuilder.artworkFilename(for: persistentID)
        let artworkURL = artworkDirectory.appendingPathComponent(filename)
        try imageData.write(to: artworkURL, options: .atomic)
        return true
    }

    private static func writeFailure(_ error: Error, to exportDirectory: URL) throws {
        let failure = PhysicalLibraryExportFailure(
            schemaVersion: 1,
            error: error.localizedDescription
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(failure)
        try data.write(to: exportDirectory.appendingPathComponent("export-error.json"), options: .atomic)
    }

    private static func writeStatus(_ status: PhysicalLibraryExportStatus, to exportDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(status)
        try data.write(to: exportDirectory.appendingPathComponent("status.json"), options: .atomic)
    }

    private static func mediaTypeDescription(_ mediaType: MPMediaType) -> String {
        if mediaType.contains(.music) { return "Music" }
        if mediaType.contains(.podcast) { return "Podcast" }
        if mediaType.contains(.audioBook) { return "Audiobook" }
        if mediaType.contains(.anyAudio) { return "Any Audio" }
        return "Unknown"
    }
}

struct PhysicalLibraryExportSongInput: Sendable {
    let persistentID: UInt64
    let title: String?
    let artist: String?
    let album: String?
    let albumArtist: String?
    let genre: String?
    let duration: TimeInterval
    let playCount: Int
    let mediaType: String
    let hasLocalAsset: Bool
    let isCloudItem: Bool
    let playbackStoreID: String?
    let hasArtwork: Bool
}

enum PhysicalLibraryExportManifestBuilder {
    static func makeManifestData(from inputs: [PhysicalLibraryExportSongInput]) throws -> Data {
        let manifest = makeManifest(from: inputs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(manifest)
    }

    static func makeManifest(from inputs: [PhysicalLibraryExportSongInput]) -> PhysicalLibraryExportManifest {
        let songs = inputs
            .map(makeSong(from:))
            .sorted { lhs, rhs in
                isOrderedBefore(lhs, rhs)
            }

        return PhysicalLibraryExportManifest(schemaVersion: 1, songs: songs)
    }

    static func artworkFilename(for persistentID: UInt64) -> String {
        "\(persistentIDHex(for: persistentID)).png"
    }

    private static func makeSong(from input: PhysicalLibraryExportSongInput) -> PhysicalLibraryExportSong {
        let persistentIDHex = persistentIDHex(for: input.persistentID)

        return PhysicalLibraryExportSong(
            persistentID: String(input.persistentID),
            persistentIDHex: persistentIDHex,
            title: cleaned(input.title, fallback: "Unknown Title"),
            artist: cleaned(input.artist, fallback: "Unknown Artist"),
            album: cleaned(input.album, fallback: "Unknown Album"),
            albumArtist: cleanedOptional(input.albumArtist),
            genre: cleanedOptional(input.genre),
            duration: input.duration,
            playCount: input.playCount,
            mediaType: input.mediaType,
            hasLocalAsset: input.hasLocalAsset,
            isCloudItem: input.isCloudItem,
            playbackStoreID: cleanedOptional(input.playbackStoreID),
            hasArtwork: input.hasArtwork,
            artworkPath: input.hasArtwork ? "artwork/\(persistentIDHex).png" : nil
        )
    }

    private static func isOrderedBefore(_ lhs: PhysicalLibraryExportSong, _ rhs: PhysicalLibraryExportSong) -> Bool {
        let lhsKey = [lhs.title, lhs.artist, lhs.album, lhs.persistentID]
        let rhsKey = [rhs.title, rhs.artist, rhs.album, rhs.persistentID]

        for (left, right) in zip(lhsKey, rhsKey) {
            if left == right { continue }
            return left < right
        }

        return false
    }

    private static func persistentIDHex(for persistentID: UInt64) -> String {
        String(format: "%016llX", persistentID)
    }

    private static func cleaned(_ value: String?, fallback: String) -> String {
        cleanedOptional(value) ?? fallback
    }

    private static func cleanedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct PhysicalLibraryExportManifest: Codable {
    let schemaVersion: Int
    let songs: [PhysicalLibraryExportSong]
}

struct PhysicalLibraryExportSong: Codable {
    let persistentID: String
    let persistentIDHex: String
    let title: String
    let artist: String
    let album: String
    let albumArtist: String?
    let genre: String?
    let duration: TimeInterval
    let playCount: Int
    let mediaType: String
    let hasLocalAsset: Bool
    let isCloudItem: Bool
    let playbackStoreID: String?
    let hasArtwork: Bool
    let artworkPath: String?
}

struct PhysicalLibraryExportSummary: Sendable {
    let songCount: Int
    let songsWithPlayCounts: Int
    let songsWithArtwork: Int
    let relativeManifestPath: String
}

struct PhysicalLibraryExportStatus: Codable {
    let schemaVersion: Int
    let runID: String?
    let state: String
    let message: String
    let songCount: Int?
    let songsWithPlayCounts: Int?
    let songsWithArtwork: Int?
    let relativeManifestPath: String?

    init(
        schemaVersion: Int = 1,
        runID: String? = nil,
        state: String,
        message: String,
        songCount: Int? = nil,
        songsWithPlayCounts: Int? = nil,
        songsWithArtwork: Int? = nil,
        relativeManifestPath: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.state = state
        self.message = message
        self.songCount = songCount
        self.songsWithPlayCounts = songsWithPlayCounts
        self.songsWithArtwork = songsWithArtwork
        self.relativeManifestPath = relativeManifestPath
    }
}

struct PhysicalLibraryExportFailure: Codable {
    let schemaVersion: Int
    let error: String
}

enum PhysicalLibraryExportError: LocalizedError {
    case mediaLibraryPermissionDenied(status: String)
    case noReadableLibrarySongs

    var errorDescription: String? {
        switch self {
        case .mediaLibraryPermissionDenied(let status):
            return "Media Library permission was not authorized (\(status))."
        case .noReadableLibrarySongs:
            return "No readable Library Songs were returned by MPMediaQuery.songs()."
        }
    }
}

extension MPMediaLibraryAuthorizationStatus {
    var exportDescription: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .authorized:
            return "authorized"
        @unknown default:
            return "unknown"
        }
    }
}
#endif
