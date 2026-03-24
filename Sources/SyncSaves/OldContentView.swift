import SwiftUI
import SyncSavesCore

struct ContentView: View {
    @EnvironmentObject var syncManager: SyncManager
    @EnvironmentObject var settings: SettingsManager
    @State private var isSyncing = false
    @State private var syncStatus: String = "Ready to sync"
    @State private var lastSyncTime: Date?
    @State private var showingSettings = false
    @State private var showingSyncAlert = false
    @State private var syncAlertTitle = ""
    @State private var syncAlertMessage = ""
    @State private var syncAlertType: AlertType = .success
    
    enum AlertType {
        case success
        case error
    }
    
    private var syncStatusColor: Color {
        if isSyncing {
            return .blue
        } else if syncStatus.contains("failed") || syncStatus.contains("Failed") {
            return .red
        } else if syncStatus.contains("success") || syncStatus.contains("Success") || syncStatus.contains("completed") {
            return .green
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("SyncSaves")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Multi-system save synchronizer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // System selector
                Picker("System", selection: $settings.selectedSystem) {
                    ForEach(GameSystem.allCases) { system in
                        Text(system.displayName)
                            .tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Status panel
                VStack(alignment: .leading, spacing: 12) {
                    StatusRow(title: "Game:", value: settings.currentGameName)
                    StatusRow(title: "OpenEmu:", value: settings.currentOpenEmuPath.isEmpty ? "Not set" : settings.currentOpenEmuPath)
                    StatusRow(title: "Cloud:", value: settings.currentCloudPath.isEmpty ? "Not set" : settings.currentCloudPath)
                    
                    if settings.selectedSystem == .ds {
                        StatusRow(title: "3DS FTP:", value: settings.ftpHost.isEmpty ? "Not set" : "\(settings.ftpHost):\(settings.ftpPort)")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                
                // Sync button and status
                VStack(spacing: 10) {
                    Button(action: syncNow) {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSyncing ? "Syncing..." : "Sync Now")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSyncing ? Color.blue.opacity(0.7) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSyncing || !settings.isConfigured)
                    
                    // Sync all systems button
                    if settings.configuredSystems.count > 1 {
                        Button("Sync All Systems") {
                            syncAllSystems()
                        }
                        .disabled(isSyncing)
                        .foregroundColor(.secondary)
                    }
                    
                    if let lastSyncTime = lastSyncTime {
                        Text("Last sync: \(lastSyncTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(syncStatus)
                        .font(.caption)
                        .foregroundColor(syncStatusColor)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 40)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Recent sync results
                if !syncManager.lastSyncResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Syncs")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(syncManager.lastSyncResults.prefix(3), id: \.timestamp) { result in
                                    SyncResultRow(result: result)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 120)
                    }
                }
                
                // Settings link
                #if os(macOS)
                HStack {
                    Spacer()
                    Button("Settings") {
                        showingSettings = true
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                #else
                NavigationLink("Settings", destination: SettingsView())
                    .padding()
                #endif
            }
            .navigationTitle("SyncSaves")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(settings)
            }
            .alert(syncAlertTitle, isPresented: $showingSyncAlert) {
                Button("OK") { }
            } message: {
                Text(syncAlertMessage)
            }
        }
    }
    
    private func syncNow() {
        isSyncing = true
        syncStatus = "Starting \(settings.selectedSystem.displayName) sync..."
        
        Task {
            do {
                try await syncManager.performSync(for: settings.selectedSystem)
                syncStatus = "\(settings.selectedSystem.displayName) sync completed successfully"
                lastSyncTime = Date()
                
                // Show success alert
                await MainActor.run {
                    syncAlertTitle = "Sync Successful"
                    syncAlertMessage = "Successfully synchronized \(settings.selectedSystem.displayName) saves"
                    syncAlertType = .success
                    showingSyncAlert = true
                }
            } catch {
                syncStatus = "Sync failed: \(error.localizedDescription)"
                
                // Show error alert
                await MainActor.run {
                    syncAlertTitle = "Sync Failed"
                    syncAlertMessage = error.localizedDescription
                    syncAlertType = .error
                    showingSyncAlert = true
                }
            }
            isSyncing = false
        }
    }
    
    private func syncAllSystems() {
        isSyncing = true
        syncStatus = "Starting sync for all configured systems..."
        
        Task {
            do {
                try await syncManager.performSync()
                syncStatus = "All systems synced successfully"
                lastSyncTime = Date()
                
                // Show success alert
                await MainActor.run {
                    syncAlertTitle = "Sync Successful"
                    syncAlertMessage = "Successfully synchronized all configured systems"
                    syncAlertType = .success
                    showingSyncAlert = true
                }
            } catch {
                syncStatus = "Sync failed: \(error.localizedDescription)"
                
                // Show error alert
                await MainActor.run {
                    syncAlertTitle = "Sync Failed"
                    syncAlertMessage = error.localizedDescription
                    syncAlertType = .error
                    showingSyncAlert = true
                }
            }
            isSyncing = false
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }
}

struct SyncResultRow: View {
    let result: SyncResult
    
    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.system.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(result.message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(result.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

#Preview {
    ContentView()
        .environmentObject(SyncManager())
        .environmentObject(SettingsManager())
}