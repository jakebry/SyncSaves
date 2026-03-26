import SwiftUI
import SyncSavesCore

@main
struct SyncSavesApp: App {
    @StateObject private var syncManager = SyncManager()
    @StateObject private var settings = SettingsManager()
    @StateObject private var gameMappingManager = GameMappingManager()
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
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
        .commands {
            // Add standard Edit menu for text operations
            CommandGroup(replacing: .textEditing) {
                Button("Cut") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x")
                
                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c")
                
                Button("Paste") {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v")
                
                Button("Select All") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a")
            }
        }
        
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

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate the app to become key application
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure the app can receive key events
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
#endif