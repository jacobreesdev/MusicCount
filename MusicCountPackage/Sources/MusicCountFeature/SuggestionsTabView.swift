import SwiftUI

@MainActor
struct SuggestionsTabView: View {
    @Environment(MusicLibraryService.self) private var musicLibraryService
    @Environment(SuggestionsService.self) private var suggestionsService
    @Environment(SongsToRemovePlaylistService.self) private var songsToRemovePlaylistService
    @State private var selectedSuggestion: Suggestion?
    @State private var sortOption: SuggestionSortOption = .playCountDifference
    @State private var searchText = ""
    @State private var completingRepairIDs: Set<String> = []
    @State private var completionMessage = ""
    @State private var completionErrorMessage = ""
    @State private var showingCompletionAlert = false
    @State private var showingCompletionErrorAlert = false
    @State private var isRetryingPlaylistSync = false
    @State private var playlistRetryMessage = ""
    @State private var playlistRetryErrorMessage = ""
    @State private var showingPlaylistRetryAlert = false
    @State private var showingPlaylistRetryErrorAlert = false

    private var filteredAndSortedSuggestions: [Suggestion] {
        let filtered: [Suggestion]
        if searchText.isEmpty {
            filtered = suggestionsService.activeSuggestions
        } else {
            filtered = suggestionsService.activeSuggestions.filter { suggestion in
                suggestion.sharedTitle.localizedStandardContains(searchText) ||
                suggestion.songs.contains { song in
                    song.artist.localizedStandardContains(searchText) ||
                    song.album.localizedStandardContains(searchText)
                }
            }
        }
        return sortOption.sorted(filtered)
    }

    private var hasRepairWork: Bool {
        suggestionsService.activeRepairs.isEmpty == false ||
            suggestionsService.activeSuggestions.isEmpty == false ||
            songsToRemovePlaylistService.syncProblem != nil
    }

    private var isShowingSearchEmptyState: Bool {
        searchText.isEmpty == false && hasRepairWork
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedSuggestion) { suggestion in
            NavigationStack {
                SuggestionRepairView(suggestion: suggestion) {
                    selectedSuggestion = nil
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Repair Marked Done", isPresented: $showingCompletionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(completionMessage)
        }
        .alert("Unable to Mark Repair Done", isPresented: $showingCompletionErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(completionErrorMessage)
        }
        .alert("Playlist Sync Updated", isPresented: $showingPlaylistRetryAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(playlistRetryMessage)
        }
        .alert("Playlist Sync Failed", isPresented: $showingPlaylistRetryErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(playlistRetryErrorMessage)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            switch musicLibraryService.authorizationState {
            case .notDetermined:
                loadingView(
                    title: "Requesting Permission",
                    message: "Please allow access to your music library when prompted."
                )
            case .denied:
                unavailableView(
                    title: "Access Denied",
                    message: "Music library access was denied. Please enable it in Settings > Privacy & Security > Media & Apple Music.",
                    systemImage: "exclamationmark.triangle",
                    color: .red
                )
            case .restricted:
                unavailableView(
                    title: "Access Restricted",
                    message: "Music library access is restricted by device policies or parental controls.",
                    systemImage: "lock.shield",
                    color: .orange
                )
            case .authorized:
                authorizedContentView
            }
        }
    }

    @ViewBuilder
    private var authorizedContentView: some View {
        switch musicLibraryService.loadingState {
        case .idle, .loading:
            loadingView(
                title: "Loading Music Library",
                message: "Finding Duplicate Groups with Play Count Gaps."
            )
        case .loaded:
            repairContentView
        case .error(let message):
            unavailableView(
                title: "Library Unavailable",
                message: message,
                systemImage: "exclamationmark.circle",
                color: .orange
            )
        }
    }

    @ViewBuilder
    private var repairContentView: some View {
        Group {
            if hasRepairWork == false {
                emptyStateView
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                repairWorkList
                    .toolbar {
                        if filteredAndSortedSuggestions.isEmpty == false {
                            ToolbarItem(placement: .primaryAction) {
                                Menu {
                                    Picker("Sort", selection: $sortOption) {
                                        ForEach(SuggestionSortOption.allCases) { option in
                                            Label(option.displayName, systemImage: option.icon(isSelected: option == sortOption)).tag(option)
                                        }
                                    }
                                } label: {
                                    Label("Sort", systemImage: "arrow.up.arrow.down")
                                }
                            }
                        }
                    }
            }
        }
    }

    private func loadingView(title: String, message: String) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private func unavailableView(
        title: String,
        message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 80))
                .foregroundStyle(color)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private var repairWorkList: some View {
        List {
            if suggestionsService.activeRepairs.isEmpty,
               let syncProblem = songsToRemovePlaylistService.syncProblem {
                Section {
                    PlaylistSyncProblemRow(
                        problem: syncProblem,
                        isRetrying: isRetryingPlaylistSync
                    ) {
                        Task {
                            await retrySongsToRemovePlaylistSync()
                        }
                    }
                } header: {
                    Text("Songs to Remove Playlist")
                }
            }

            if suggestionsService.activeRepairs.isEmpty == false {
                Section {
                    if let syncProblem = songsToRemovePlaylistService.syncProblem {
                        PlaylistSyncProblemRow(
                            problem: syncProblem,
                            isRetrying: isRetryingPlaylistSync
                        ) {
                            Task {
                                await retrySongsToRemovePlaylistSync()
                            }
                        }
                    }

                    ForEach(suggestionsService.activeRepairs) { activeRepair in
                        ActiveRepairRow(
                            activeRepair: activeRepair,
                            isCompleting: completingRepairIDs.contains(activeRepair.id)
                        ) {
                            Task {
                                await markActiveRepairDone(activeRepair)
                            }
                        }
                    }
                } header: {
                    Text("Active Repairs")
                        .accessibilityIdentifier(AccessibilityIdentifiers.Suggestions.activeRepairsSection)
                }
            }

            ForEach(filteredAndSortedSuggestions) { suggestion in
                Section {
                    if suggestion.canDismissIndividualSongs {
                        // 3+ songs: Individual rows with individual swipes
                        ForEach(suggestion.songs) { song in
                            Button {
                                selectedSuggestion = suggestion
                            } label: {
                                SongRowView(song: song, selectionSlot: nil)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation(.easeOut) {
                                        suggestionsService.dismissSong(
                                            title: suggestion.sharedTitle,
                                            artist: suggestion.sharedArtist,
                                            songId: song.id
                                        )
                                    }
                                } label: {
                                    Label("Dismiss", systemImage: "xmark.circle")
                                }
                            }
                        }
                    } else {
                        // 2 songs: Single container with all songs, entire thing is swipeable
                        SuggestionGroupContainer(
                            suggestion: suggestion,
                            onTap: {
                                selectedSuggestion = suggestion
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation(.easeOut) {
                                    suggestionsService.dismissEntireGroup(
                                        title: suggestion.sharedTitle,
                                        artist: suggestion.sharedArtist
                                    )
                                }
                            } label: {
                                Label("Dismiss All", systemImage: "xmark.circle.fill")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(suggestion.sharedTitle)
                            .font(.headline)
                            .textCase(nil)
                        Spacer()
                        Text(suggestion.versionCount)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .contentMargins(.top, 0, for: .scrollContent)
        .accessibilityIdentifier(AccessibilityIdentifiers.Suggestions.suggestionsList)
        .overlay {
            if suggestionsService.activeRepairs.isEmpty &&
                filteredAndSortedSuggestions.isEmpty &&
                songsToRemovePlaylistService.syncProblem == nil {
                emptyStateView
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "Search suggestions")
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Text(isShowingSearchEmptyState ? "No Matching Suggestions" : "No Suggestions")
                .font(.title2.weight(.semibold))
        } description: {
            Text(emptyStateDescription)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyStateDescription: String {
        if isShowingSearchEmptyState {
            return "No suggestions match '\(searchText)'"
        }

        return suggestionsService.allSuggestions.isEmpty
            ? "No duplicate songs found"
            : "All suggestions reviewed"
    }

    private func markActiveRepairDone(_ activeRepair: ActiveRepair) async {
        guard completingRepairIDs.contains(activeRepair.id) == false else { return }

        completingRepairIDs.insert(activeRepair.id)
        defer {
            completingRepairIDs.remove(activeRepair.id)
        }

        do {
            let workflow = ActiveRepairCompletionWorkflow(
                suggestionsService: suggestionsService,
                songsToRemovePlaylistService: songsToRemovePlaylistService
            )
            let result = try await workflow.markActiveRepairDone(id: activeRepair.id)
            completionMessage = completionMessage(for: result)
            showingCompletionAlert = true
        } catch {
            completionErrorMessage = error.localizedDescription
            showingCompletionErrorAlert = true
        }
    }

    private func retrySongsToRemovePlaylistSync() async {
        guard isRetryingPlaylistSync == false else { return }

        isRetryingPlaylistSync = true
        defer {
            isRetryingPlaylistSync = false
        }

        let workflow = ActiveRepairPlaylistSyncWorkflow(
            suggestionsService: suggestionsService,
            songsToRemovePlaylistService: songsToRemovePlaylistService
        )
        let result = await workflow.resyncSongsToRemovePlaylist()

        switch result {
        case .synced:
            playlistRetryMessage = "Songs to Remove Playlist is up to date."
            showingPlaylistRetryAlert = true
        case .failed(let message):
            playlistRetryErrorMessage = message
            showingPlaylistRetryErrorAlert = true
        }
    }

    private func completionMessage(for result: ActiveRepairCompletionWorkflowResult) -> String {
        let baseMessage = "\(result.completedRepair.suggestionTitle) was marked done. MusicCount will keep this Suggestion out of normal review."

        switch result.playlistSync {
        case .synced:
            return "\(baseMessage) Its Retired Songs were removed from the Songs to Remove Playlist."
        case .failed:
            return """
            \(baseMessage)

            The Active Repair was marked done, but MusicCount could not update the Songs to Remove Playlist. You can retry playlist sync later.
            """
        }
    }
}

// MARK: - Active Repair Row

private struct PlaylistSyncProblemRow: View {
    let problem: SongsToRemovePlaylistSyncProblem
    let isRetrying: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Songs to Remove Playlist May Be Stale", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(problem.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                onRetry()
            } label: {
                Label(isRetrying ? "Retrying" : "Retry Playlist Sync", systemImage: isRetrying ? "hourglass" : "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isRetrying)
        }
        .padding(.vertical, 4)
    }
}

private struct ActiveRepairRow: View {
    let activeRepair: ActiveRepair
    let isCompleting: Bool
    let onMarkDone: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeRepair.suggestionTitle)
                            .font(.headline)
                            .lineLimit(2)

                        Text(activeRepair.suggestionArtist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Label("\(activeRepair.repairAmount.formatted())", systemImage: "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(activeRepair.canonicalSong.title, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary)

                    Label(retiredSongsSummary, systemImage: "tray.fill")
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .font(.caption)
            }

            Button {
                onMarkDone()
            } label: {
                Label(isCompleting ? "Marking" : "Done", systemImage: isCompleting ? "hourglass" : "checkmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isCompleting)
            .accessibilityIdentifier(AccessibilityIdentifiers.Suggestions.markActiveRepairDoneButton(id: activeRepair.id))
            .accessibilityHint("Mark this Active Repair as a Completed Repair")
        }
        .padding(.vertical, 4)
    }

    private var retiredSongsSummary: String {
        let titles = activeRepair.retiredSongs.map(\.title).joined(separator: ", ")
        return "\(activeRepair.retiredSongs.count) Retired Songs: \(titles)"
    }
}

// MARK: - Suggestion Group Container

private struct SuggestionGroupContainer: View {
    let suggestion: Suggestion
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 0) {
                ForEach(suggestion.songs) { song in
                    SongRowView(song: song, selectionSlot: nil)

                    // Add divider between songs (but not after last one)
                    if song.id != suggestion.songs.last?.id {
                        Divider()
                            .padding(.leading, 62) // Align with text, not artwork
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Suggestion Sort Options

enum SuggestionSortOption: String, CaseIterable, Identifiable, Sendable {
    case playCountDifference = "playCountDifference"
    case titleAscending = "titleAscending"
    case titleDescending = "titleDescending"
    case artistAscending = "artistAscending"
    case artistDescending = "artistDescending"
    case versionCountDescending = "versionCountDescending"
    case versionCountAscending = "versionCountAscending"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .playCountDifference:
            return "Play Count Difference"
        case .titleAscending, .titleDescending:
            return "Title"
        case .artistAscending, .artistDescending:
            return "Artist"
        case .versionCountDescending, .versionCountAscending:
            return "Version Count"
        }
    }

    func sorted(_ suggestions: [Suggestion]) -> [Suggestion] {
        switch self {
        case .playCountDifference:
            return suggestions.sorted { $0.playCountDifference > $1.playCountDifference }
        case .titleAscending:
            return suggestions.sorted { $0.sharedTitle.localizedStandardCompare($1.sharedTitle) == .orderedAscending }
        case .titleDescending:
            return suggestions.sorted { $0.sharedTitle.localizedStandardCompare($1.sharedTitle) == .orderedDescending }
        case .artistAscending:
            return suggestions.sorted { $0.sharedArtist.localizedStandardCompare($1.sharedArtist) == .orderedAscending }
        case .artistDescending:
            return suggestions.sorted { $0.sharedArtist.localizedStandardCompare($1.sharedArtist) == .orderedDescending }
        case .versionCountDescending:
            return suggestions.sorted { $0.songs.count > $1.songs.count }
        case .versionCountAscending:
            return suggestions.sorted { $0.songs.count < $1.songs.count }
        }
    }

    func icon(isSelected: Bool) -> String {
        let suffix = isSelected ? ".fill" : ""
        switch self {
        case .playCountDifference, .versionCountDescending, .titleDescending, .artistDescending:
            return "arrow.down.circle\(suffix)"
        case .titleAscending, .artistAscending, .versionCountAscending:
            return "arrow.up.circle\(suffix)"
        }
    }
}
