import SwiftUI
import SyncSavesCore

@main
struct SyncSavesApp: App {
    @StateObject private var syncManager = SyncManager()
    @StateObject private var settings = SettingsManager()
    @StateObject private var gameMappingManager = GameMappingManager()
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            if hasCompletedSetup {
                ContentView()
                    .environmentObject(syncManager)
                    .environmentObject(settings)
                    .environmentObject(gameMappingManager)
            } else {
                OnboardingView()
                    .environmentObject(syncManager)
                    .environmentObject(settings)
                    .environmentObject(gameMappingManager)
            }
        }
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(gameMappingManager)
        }
        #else
        WindowGroup {
            if hasCompletedSetup {
                ContentView()
                    .environmentObject(syncManager)
                    .environmentObject(settings)
                    .environmentObject(gameMappingManager)
            } else {
                OnboardingView()
                    .environmentObject(syncManager)
                    .environmentObject(settings)
                    .environmentObject(gameMappingManager)
            }
        }
        #endif
    }
}