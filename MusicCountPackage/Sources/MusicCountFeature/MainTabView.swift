import SwiftUI

/// Root tab view containing Suggestions, Library, and Settings tabs.
public struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var musicLibraryService = MusicLibraryServiceFactory.create()
    @State private var queueService = AppleMusicQueueService()
    @State private var suggestionsService = SuggestionsService()
    @State private var songsToRemovePlaylistService = SongsToRemovePlaylistService()

    public var body: some View {
        TabView(selection: $selectedTab) {
            SuggestionsTabView()
                .tabItem {
                    Label("Suggestions", systemImage: "lightbulb.fill")
                }
                .badge(suggestionsService.activeSuggestions.count)
                .tag(0)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.suggestionsTab)

            LibraryTabView()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
                .tag(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.libraryTab)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.settingsTab)
        }
        .environment(musicLibraryService)
        .environment(queueService)
        .environment(suggestionsService)
        .environment(songsToRemovePlaylistService)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .task {
            await prepareMusicLibrary()
        }
        .onChange(of: musicLibraryService.authorizationState) { _, newState in
            if newState == .authorized {
                Task {
                    await loadMusicLibraryIfNeeded()
                }
            }
        }
        .onChange(of: musicLibraryService.loadingState) { _, newState in
            if case .loaded(let songs) = newState {
                suggestionsService.analyzeSongs(songs)
            }
        }
    }

    public init() {}

    private func prepareMusicLibrary() async {
        if musicLibraryService.authorizationState == .notDetermined {
            await musicLibraryService.requestAuthorization()
        }

        if musicLibraryService.authorizationState == .authorized {
            await loadMusicLibraryIfNeeded()
        }
    }

    private func loadMusicLibraryIfNeeded() async {
        if case .idle = musicLibraryService.loadingState {
            await musicLibraryService.loadMusicLibrary()
        }
    }
}
