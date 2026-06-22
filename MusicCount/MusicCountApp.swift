import SwiftUI
import MusicCountFeature

@main
struct MusicCountApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if PhysicalLibraryExportLaunch.isRequested {
                PhysicalLibraryExportView()
            } else {
                MainTabView()
            }
            #else
            MainTabView()
            #endif
        }
    }
}
