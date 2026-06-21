import SwiftUI

/// Root tab view containing Library, Suggestions, and Settings tabs.
public struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var queueService = AppleMusicQueueService()
    @State private var suggestionsService = SuggestionsService()
    @State private var songsToRemovePlaylistService = SongsToRemovePlaylistService()

    public var body: some View {
        TabView(selection: $selectedTab) {
            LibraryTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
                .tag(0)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.libraryTab)

            SuggestionsTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Suggestions", systemImage: "lightbulb.fill")
                }
                .badge(suggestionsService.activeSuggestions.count)
                .tag(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.suggestionsTab)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.settingsTab)
        }
        .environment(queueService)
        .environment(suggestionsService)
        .environment(songsToRemovePlaylistService)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    public init() {}
}
