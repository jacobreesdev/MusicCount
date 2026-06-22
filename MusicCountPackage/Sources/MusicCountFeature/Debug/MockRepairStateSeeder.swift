#if DEBUG
import Foundation

enum MockRepairStateSeeder {
    static func seedActiveRepairsIfRequested() {
        resetRepairStateIfRequested()

        guard ProcessInfo.processInfo.arguments.contains("-MockActiveRepairs") else { return }

        do {
            let data = try JSONEncoder().encode(MockScenarioCatalog.activeRepairs)
            UserDefaults.standard.set(data, forKey: StorageKeys.activeRepairs)
        } catch {
            UserDefaults.standard.removeObject(forKey: StorageKeys.activeRepairs)
        }
    }

    private static func resetRepairStateIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ResetRepairState") || arguments.contains("-MockActiveRepairs") else { return }

        UserDefaults.standard.removeObject(forKey: StorageKeys.dismissedSuggestions)
        UserDefaults.standard.removeObject(forKey: StorageKeys.activeRepairs)
        UserDefaults.standard.removeObject(forKey: StorageKeys.completedRepairs)
        UserDefaults.standard.removeObject(forKey: StorageKeys.songsToRemovePlaylistID)
    }

}
#endif
