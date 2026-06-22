import SwiftUI

struct LibraryTabView: View {
    @Environment(MusicLibraryService.self) private var service
    @State private var selectedSong: SongInfo?
    @State private var showingManualQueue = false
    @State private var sortOption: SortOption = .playCountDescending
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                switch service.authorizationState {
                case .notDetermined:
                    unauthorizedView
                case .denied:
                    deniedView
                case .restricted:
                    restrictedView
                case .authorized:
                    authorizedView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingManualQueue) {
                if let song = selectedSong {
                    ManualQueueView(song: song, showingManualQueue: $showingManualQueue)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - Authorization Views

    private var unauthorizedView: some View {
        MusicCountLoadingStateView(
            title: "Requesting Permission",
            message: "Please allow access to your music library when prompted."
        )
    }

    private var deniedView: some View {
        MusicCountUnavailableStateView(
            title: "Access Denied",
            message: "Music library access was denied. Please enable it in Settings > Privacy & Security > Media & Apple Music.",
            systemImage: "exclamationmark.triangle",
            color: .red
        )
    }

    private var restrictedView: some View {
        MusicCountUnavailableStateView(
            title: "Access Restricted",
            message: "Music library access is restricted by device policies or parental controls.",
            systemImage: "lock.shield",
            color: .orange
        )
    }

    private var authorizedView: some View {
        Group {
            switch service.loadingState {
            case .idle, .loading:
                loadingView
            case .loaded(let songs):
                libraryView(songs: songs)
            case .error(let message):
                errorView(message: message)
            }
        }
    }

    // MARK: - Loading States

    private var loadingView: some View {
        MusicCountLoadingStateView(
            title: "Loading Music Library",
            message: "Finding Library Songs for browsing and manual queueing."
        )
    }

    private func errorView(message: String) -> some View {
        MusicCountUnavailableStateView(
            title: "Library Unavailable",
            message: message,
            systemImage: "exclamationmark.circle",
            color: .orange
        ) {
            Button {
                Task {
                    await service.loadMusicLibrary()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func libraryView(songs: [SongInfo]) -> some View {
        let filtered = filteredSongs(from: songs)

        return List {
            ForEach(filtered) { song in
                SongRowView(
                    song: song,
                    selectionSlot: selectionSlot(for: song)
                )
                .swipeActions(edge: .trailing) {
                    Button {
                        toggleManualQueueSelection(song)
                    } label: {
                        if selectedSong?.id == song.id {
                            Label("Deselect", systemImage: "xmark.circle.fill")
                        } else {
                            Label("Select for Manual Queue", systemImage: "plus.circle.fill")
                        }
                    }
                    .tint(selectedSong?.id == song.id ? .orange : .blue)
                }
                .contextMenu {
                    Button {
                        toggleManualQueueSelection(song)
                    } label: {
                        if selectedSong?.id == song.id {
                            Label("Deselect Manual Queue Song", systemImage: "xmark.circle.fill")
                        } else {
                            Label("Select for Manual Queue", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .contentMargins(.top, 0, for: .scrollContent)
        .overlay {
            if filtered.isEmpty {
                emptyLibraryState
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "Search songs")
        .overlay(alignment: .bottom) {
            if filtered.isEmpty == false {
                FloatingActionButton(
                    selectedCount: selectionCount,
                    isEnabled: selectedSong != nil,
                    action: {
                        showingManualQueue = true
                    }
                )
                .opacity(showingManualQueue ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: showingManualQueue)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Label(option.displayName, systemImage: option.icon(isSelected: option == sortOption)).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                clearButton
            }
        }
    }

    private var emptyLibraryState: some View {
        ContentUnavailableView {
            Text(searchText.isEmpty ? "No Songs Found" : "No Matching Songs")
                .font(.title2.weight(.semibold))
        } description: {
            Text(searchText.isEmpty
                ? "Your music library is empty"
                : "No songs match '\(searchText)'")
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Action Buttons

    private var clearButton: some View {
        Button(role: .destructive) {
            selectedSong = nil
        } label: {
            Label("Clear Selection", systemImage: "xmark.circle")
        }
        .disabled(selectedSong == nil)
    }

    // MARK: - Helper Methods

    private func selectionSlot(for song: SongInfo) -> Int? {
        if selectedSong?.id == song.id {
            return 1
        }
        return nil
    }

    private var selectionCount: Int {
        selectedSong == nil ? 0 : 1
    }

    private func toggleManualQueueSelection(_ song: SongInfo) {
        if selectedSong?.id == song.id {
            selectedSong = nil
        } else {
            selectedSong = song
        }
    }

    private func filteredSongs(from songs: [SongInfo]) -> [SongInfo] {
        var filtered = songs

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { song in
                song.title.localizedStandardContains(searchText) ||
                song.artist.localizedStandardContains(searchText) ||
                song.album.localizedStandardContains(searchText)
            }
        }

        // Apply sorting
        return sortOption.sorted(filtered)
    }
}

#if DEBUG
#Preview("Library - Loading") {
    LibraryTabView()
        .musicCountPreviewEnvironment(
            loadingState: .loading
        )
}

#Preview("Library - Populated") {
    LibraryTabView()
        .musicCountPreviewEnvironment()
}

#Preview("Library - Long Library Song Metadata") {
    LibraryTabView()
        .musicCountPreviewEnvironment(
            loadingState: .loaded([
                MusicCountPreviewData.longLibrarySong,
            ])
        )
}

#Preview("Library - Empty") {
    LibraryTabView()
        .musicCountPreviewEnvironment(
            loadingState: .loaded([])
        )
}

#Preview("Library - Error") {
    LibraryTabView()
        .musicCountPreviewEnvironment(
            loadingState: .error("MusicCount could not load the preview music library.")
        )
}

#Preview("Library - Access Denied") {
    LibraryTabView()
        .musicCountPreviewEnvironment(
            authorizationState: .denied,
            loadingState: .idle
        )
}

#Preview("Library - Access Restricted") {
    LibraryTabView()
        .musicCountPreviewEnvironment(
            authorizationState: .restricted,
            loadingState: .idle
        )
}
#endif
