import Foundation

/// Finds duplicate songs with different play counts and manages dismissals.
@MainActor
@Observable
final class SuggestionsService: Sendable {
    private(set) var allSuggestions: [Suggestion] = []
    private(set) var activeRepairs: [ActiveRepair] = []
    private var dismissedKeys: Set<String> = []
    private let dismissedKeysKey = StorageKeys.dismissedSuggestions
    private let activeRepairsKey = StorageKeys.activeRepairs

    init() {
        loadDismissedKeys()
        loadActiveRepairs()
    }

    /// Active suggestions sorted by play count difference (largest first).
    var activeSuggestions: [Suggestion] {
        allSuggestions
            .compactMap { suggestion in
                let groupKey = suggestionKey(title: suggestion.sharedTitle, artist: suggestion.sharedArtist)

                if activeRepairs.contains(where: { $0.id == groupKey }) {
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
        // Group songs by normalized title AND artist
        var titleArtistGroups: [String: [SongInfo]] = [:]

        for song in songs {
            let groupKey = suggestionKey(title: song.title, artist: song.artist)
            titleArtistGroups[groupKey, default: []].append(song)
        }

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

        guard activeRepairs.contains(where: { $0.id == key }) == false else {
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

    /// Clears all dismissals, restoring suggestions to the active list.
    func resetDismissals() {
        dismissedKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: dismissedKeysKey)
    }

    private func normalizeTitle(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeArtist(_ artist: String) -> String {
        artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func suggestionKey(title: String, artist: String) -> String {
        "\(normalizeTitle(title))-\(normalizeArtist(artist))"
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
}
