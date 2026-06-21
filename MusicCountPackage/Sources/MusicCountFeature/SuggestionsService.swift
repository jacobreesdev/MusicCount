import Foundation

/// Finds duplicate songs with different play counts and manages dismissals.
@MainActor
@Observable
final class SuggestionsService: Sendable {
    private(set) var allSuggestions: [Suggestion] = []
    private(set) var activeRepairs: [ActiveRepair] = []
    private(set) var completedRepairs: [CompletedRepair] = []
    private var dismissedKeys: Set<String> = []
    private let dismissedKeysKey = StorageKeys.dismissedSuggestions
    private let activeRepairsKey = StorageKeys.activeRepairs
    private let completedRepairsKey = StorageKeys.completedRepairs

    init() {
        #if DEBUG
        MockRepairStateSeeder.seedActiveRepairsIfRequested()
        #endif
        loadDismissedKeys()
        loadActiveRepairs()
        loadCompletedRepairs()
    }

    /// Active suggestions sorted by play count difference (largest first).
    var activeSuggestions: [Suggestion] {
        allSuggestions
            .compactMap { suggestion in
                let groupKey = suggestionKey(title: suggestion.sharedTitle, artist: suggestion.sharedArtist)

                if hasRepairRecord(id: groupKey) {
                    return nil
                }

                // Check if entire group was dismissed
                if dismissedKeys.contains("\(groupKey)-ENTIRE_GROUP") {
                    return nil
                }

                // Filter out individually dismissed songs
                let filteredSongs = suggestion.songs.filter { song in
                    !dismissedKeys.contains("\(groupKey)-\(song.id)")
                }

                // Only show if 2+ versions remain
                guard filteredSongs.count >= 2 else { return nil }

                var filtered = suggestion
                filtered.updateSongs(filteredSongs)
                return filtered
            }
            .sorted { $0.playCountDifference > $1.playCountDifference }
    }

    /// Groups songs by normalized title/artist and creates suggestions for duplicates.
    func analyzeSongs(_ songs: [SongInfo]) {
        let titleArtistGroups = groupSongsBySuggestionKey(songs)

        // Create suggestions for groups with 2+ versions
        allSuggestions = titleArtistGroups.compactMap { _, songsInGroup in
            guard songsInGroup.count >= 2 else { return nil }

            // Use the first song's original title and artist as the shared values
            let sharedTitle = songsInGroup[0].title
            let sharedArtist = songsInGroup[0].artist

            // Sort by play count for consistent ordering
            let sortedSongs = songsInGroup.sorted { $0.playCount < $1.playCount }

            return Suggestion(
                sharedTitle: sharedTitle,
                sharedArtist: sharedArtist,
                songs: sortedSongs
            )
        }
    }

    private func groupSongsBySuggestionKey(_ songs: [SongInfo]) -> [String: [SongInfo]] {
        var exactGroups: [String: [SongInfo]] = [:]
        for song in songs {
            let groupKey = suggestionKey(title: song.title, artist: song.artist)
            exactGroups[groupKey, default: []].append(song)
        }

        var mergedGroups = exactGroups

        for (groupKey, songsInGroup) in exactGroups {
            guard
                let firstSong = songsInGroup.first,
                let baseTitle = titleWithoutTrailingParenthetical(firstSong.title)
            else { continue }

            let baseGroupKey = suggestionKey(title: baseTitle, artist: firstSong.artist)

            guard baseGroupKey != groupKey, exactGroups[baseGroupKey] != nil else {
                continue
            }

            mergedGroups[baseGroupKey, default: []].append(contentsOf: songsInGroup)
            mergedGroups[groupKey] = nil
        }

        return mergedGroups
    }

    /// Dismisses a single song version from a suggestion group.
    func dismissSong(title: String, artist: String, songId: UInt64) {
        let key = "\(suggestionKey(title: title, artist: artist))-\(songId)"
        dismissedKeys.insert(key)
        saveDismissedKeys()
    }

    /// Dismisses all versions of a song from suggestions.
    func dismissEntireGroup(title: String, artist: String) {
        let key = "\(suggestionKey(title: title, artist: artist))-ENTIRE_GROUP"
        dismissedKeys.insert(key)
        saveDismissedKeys()
    }

    /// Creates an Active Repair after a Repair Queue has been built.
    func createActiveRepair(from decision: RepairDecision, for suggestion: Suggestion) throws -> ActiveRepair {
        let key = suggestionKey(title: suggestion.sharedTitle, artist: suggestion.sharedArtist)

        guard hasRepairRecord(id: key) == false else {
            throw ActiveRepairError.alreadyExists
        }

        let activeRepair = ActiveRepair(
            id: key,
            suggestionTitle: suggestion.sharedTitle,
            suggestionArtist: suggestion.sharedArtist,
            canonicalSong: decision.canonicalSong,
            retiredSongs: decision.retiredSongs,
            repairAmount: decision.repairAmount
        )
        activeRepairs.append(activeRepair)
        saveActiveRepairs()
        return activeRepair
    }

    /// Returns whether the Suggestion already has an Active Repair.
    func hasActiveRepair(for suggestion: Suggestion) -> Bool {
        let key = suggestionKey(title: suggestion.sharedTitle, artist: suggestion.sharedArtist)
        return hasActiveRepair(id: key)
    }

    /// Marks an Active Repair as done after the user completes follow-through outside MusicCount.
    func markActiveRepairDone(id: String) throws -> CompletedRepair {
        guard let activeRepairIndex = activeRepairs.firstIndex(where: { $0.id == id }) else {
            throw ActiveRepairError.notFound
        }

        let activeRepair = activeRepairs.remove(at: activeRepairIndex)
        let completedRepair = CompletedRepair(activeRepair: activeRepair)

        if completedRepairs.contains(where: { $0.id == completedRepair.id }) == false {
            completedRepairs.append(completedRepair)
        }

        saveActiveRepairs()
        saveCompletedRepairs()
        return completedRepair
    }

    /// Clears all dismissals, restoring suggestions to the active list.
    func resetDismissals() {
        dismissedKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: dismissedKeysKey)
    }

    private func normalizeTitle(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func titleWithoutTrailingParenthetical(_ title: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.hasSuffix(")"), let openingParenthesisIndex = trimmedTitle.lastIndex(of: "(") else {
            return nil
        }

        let baseTitle = trimmedTitle[..<openingParenthesisIndex]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return baseTitle.isEmpty ? nil : String(baseTitle)
    }

    private func normalizeArtist(_ artist: String) -> String {
        artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func suggestionKey(title: String, artist: String) -> String {
        "\(normalizeTitle(title))-\(normalizeArtist(artist))"
    }

    private func hasActiveRepair(id: String) -> Bool {
        activeRepairs.contains { $0.id == id }
    }

    private func hasRepairRecord(id: String) -> Bool {
        hasActiveRepair(id: id) || completedRepairs.contains { $0.id == id }
    }

    private func loadDismissedKeys() {
        if let data = UserDefaults.standard.array(forKey: dismissedKeysKey) as? [String] {
            dismissedKeys = Set(data)
        }
    }

    private func saveDismissedKeys() {
        UserDefaults.standard.set(Array(dismissedKeys), forKey: dismissedKeysKey)
    }

    private func loadActiveRepairs() {
        guard let data = UserDefaults.standard.data(forKey: activeRepairsKey) else { return }

        do {
            activeRepairs = try JSONDecoder().decode([ActiveRepair].self, from: data)
        } catch {
            activeRepairs = []
            UserDefaults.standard.removeObject(forKey: activeRepairsKey)
        }
    }

    private func saveActiveRepairs() {
        do {
            let data = try JSONEncoder().encode(activeRepairs)
            UserDefaults.standard.set(data, forKey: activeRepairsKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: activeRepairsKey)
        }
    }

    private func loadCompletedRepairs() {
        guard let data = UserDefaults.standard.data(forKey: completedRepairsKey) else { return }

        do {
            completedRepairs = try JSONDecoder().decode([CompletedRepair].self, from: data)
        } catch {
            completedRepairs = []
            UserDefaults.standard.removeObject(forKey: completedRepairsKey)
        }
    }

    private func saveCompletedRepairs() {
        do {
            let data = try JSONEncoder().encode(completedRepairs)
            UserDefaults.standard.set(data, forKey: completedRepairsKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: completedRepairsKey)
        }
    }
}
