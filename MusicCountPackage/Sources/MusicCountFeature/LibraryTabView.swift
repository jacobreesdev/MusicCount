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
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Requesting Permission")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Please allow access to your music library when prompted.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private var deniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Access Denied")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Music library access was denied. Please enable it in Settings > Privacy & Security > Media & Apple Music.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private var restrictedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("Access Restricted")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Music library access is restricted by device policies or parental controls.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
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
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading Music Library...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("No Songs Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await service.loadMusicLibrary()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
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
