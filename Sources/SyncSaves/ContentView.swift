import SwiftUI
import SyncSavesCore

struct DiscoveredGame: Identifiable {
    let id = UUID()
    let openEmuFile: String
    let cloudFile: String?
    let system: GameSystem
    let matchConfidence: Double
    let needsManualMatch: Bool
    let mapping: GameMapping?
    
    var displayName: String {
        let baseName = openEmuFile.replacingOccurrences(of: ".\(system.fileExtension)", with: "")
        return baseName.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    var isLinked: Bool {
        cloudFile != nil && matchConfidence > 0.7
    }
}

struct NewContentView: View {
    @EnvironmentObject var syncManager: SyncManager
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var gameMappingManager: GameMappingManager
    
    @State private var discoveredGames: [DiscoveredGame] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var syncStatus = "Ready"
    @State private var lastScanTime: Date?
    @State private var showingMatchSheet = false
    @State private var selectedGameForMatching: DiscoveredGame?
    @State private var unmatchedCloudFiles: [String] = []
    @State private var selectedCloudFileForMatch = ""
    
    private let fileScanner = FileScanner()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("SyncSaves")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Discovered \(discoveredGames.count) games")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Sync status and controls
                VStack(spacing: 12) {
                    HStack {
                        Button {
                            scanForGames()
                        } label: {
                            Label("Rescan", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                        
                        Spacer()
                        
                        if let lastScanTime = lastScanTime {
                            Text("Scanned \(lastScanTime.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sync all button
                    Button {
                        syncAllGames()
                    } label: {
                        if isSyncing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                            }
                        } else {
                            Label("SYNC ALL GAMES", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSyncing || discoveredGames.filter(\.isLinked).isEmpty)
                    .padding(.horizontal)
                    
                    Text(syncStatus)
                        .font(.caption)
                        .foregroundColor(syncStatusColor)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 20)
                        .padding(.horizontal)
                }
                .padding(.bottom, 20)
                
                Divider()
                
                // Games list
                if discoveredGames.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        VStack(spacing: 8) {
                            Text("No Games Found")
                                .font(.headline)
                            
                            Text("Scan your directories to discover games")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(discoveredGames) { game in
                                GameRow(
                                    game: game,
                                    onMatchRequested: {
                                        selectedGameForMatching = game
                                        prepareUnmatchedFiles(for: game)
                                        showingMatchSheet = true
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Games")
            .sheet(isPresented: $showingMatchSheet) {
                if let game = selectedGameForMatching {
                    MatchSheetView(
                        game: game,
                        unmatchedCloudFiles: unmatchedCloudFiles,
                        selectedCloudFile: $selectedCloudFileForMatch,
                        onMatch: { cloudFile in
                            createMapping(for: game, cloudFile: cloudFile)
                            showingMatchSheet = false
                        },
                        onCancel: {
                            showingMatchSheet = false
                        }
                    )
                }
            }
            .onAppear {
                scanForGames()
            }
        }
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
    
    private func scanForGames() {
        isLoading = true
        syncStatus = "Scanning directories..."
        
        Task {
            let scanResults = fileScanner.scanAllDirectories(using: settings)
            var games: [DiscoveredGame] = []
            
            for (system, (openEmuFiles, cloudFiles)) in scanResults {
                for openEmuFile in openEmuFiles {
                    // Check if we already have a mapping
                    if let existingMapping = gameMappingManager.mapping(forOpenEmuFileName: openEmuFile) {
                        // We have an explicit mapping
                        let game = DiscoveredGame(
                            openEmuFile: openEmuFile,
                            cloudFile: existingMapping.cloudFileName,
                            system: system,
                            matchConfidence: 1.0,
                            needsManualMatch: false,
                            mapping: existingMapping
                        )
                        games.append(game)
                    } else {
                        // Try to find a fuzzy match
                        let suggestions = fileScanner.findSuggestedMappings(
                            openEmuFiles: [openEmuFile],
                            cloudFiles: cloudFiles,
                            for: system
                        )
                        
                        if let bestMatch = suggestions.first, bestMatch.score > 0.7 {
                            // High confidence match - auto-link
                            let mapping = GameMapping(
                                openEmuFileName: openEmuFile,
                                cloudFileName: bestMatch.cloudFile
                            )
                            gameMappingManager.addMapping(mapping)
                            
                            let game = DiscoveredGame(
                                openEmuFile: openEmuFile,
                                cloudFile: bestMatch.cloudFile,
                                system: system,
                                matchConfidence: bestMatch.score,
                                needsManualMatch: false,
                                mapping: mapping
                            )
                            games.append(game)
                        } else {
                            // Needs manual match
                            let game = DiscoveredGame(
                                openEmuFile: openEmuFile,
                                cloudFile: nil,
                                system: system,
                                matchConfidence: suggestions.first?.score ?? 0,
                                needsManualMatch: true,
                                mapping: nil
                            )
                            games.append(game)
                        }
                    }
                }
            }
            
            await MainActor.run {
                discoveredGames = games.sorted { $0.displayName < $1.displayName }
                lastScanTime = Date()
                isLoading = false
                syncStatus = "Found \(games.count) games"
            }
        }
    }
    
    private func prepareUnmatchedFiles(for game: DiscoveredGame) {
        let scanResults = fileScanner.scanAllDirectories(using: settings)
        guard let (_, cloudFiles) = scanResults[game.system] else {
            unmatchedCloudFiles = []
            return
        }
        
        // Filter out cloud files that are already mapped
        let mappedCloudFiles = gameMappingManager.mappings(for: game.system).map { $0.cloudFileName }
        unmatchedCloudFiles = cloudFiles.filter { !mappedCloudFiles.contains($0) }
        
        if !unmatchedCloudFiles.isEmpty {
            selectedCloudFileForMatch = unmatchedCloudFiles[0]
        }
    }
    
    private func createMapping(for game: DiscoveredGame, cloudFile: String) {
        let mapping = GameMapping(
            openEmuFileName: game.openEmuFile,
            cloudFileName: cloudFile
        )
        gameMappingManager.addMapping(mapping)
        
        // Update the discovered games list
        if let index = discoveredGames.firstIndex(where: { $0.id == game.id }) {
            discoveredGames[index] = DiscoveredGame(
                openEmuFile: game.openEmuFile,
                cloudFile: cloudFile,
                system: game.system,
                matchConfidence: 1.0,
                needsManualMatch: false,
                mapping: mapping
            )
        }
    }
    
    private func syncAllGames() {
        isSyncing = true
        syncStatus = "Starting sync for all linked games..."
        
        Task {
            do {
                // Get all linked games
                let linkedGames = discoveredGames.filter(\.isLinked)
                
                for game in linkedGames {
                    guard let mapping = game.mapping else { continue }
                    
                    // Update settings for this game temporarily
                    await MainActor.run {
                        settings.selectedSystem = game.system
                        // We need to extract game name from filename
                        let gameName = game.openEmuFile.replacingOccurrences(of: ".\(game.system.fileExtension)", with: "")
                        switch game.system {
                        case .ds: settings.dsGameName = gameName
                        case .gba: settings.gbaGameName = gameName
                        case .gbc: settings.gbcGameName = gameName
                        }
                    }
                    
                    // Perform sync for this game
                    try await syncManager.performSync(for: game.system)
                }
                
                await MainActor.run {
                    syncStatus = "Successfully synced \(linkedGames.count) games"
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    syncStatus = "Sync failed: \(error.localizedDescription)"
                    isSyncing = false
                }
            }
        }
    }
}

struct GameRow: View {
    let game: DiscoveredGame
    let onMatchRequested: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // System icon
            Image(systemName: systemIcon)
                .font(.title2)
                .foregroundColor(systemColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                // Game name
                Text(game.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                // Status
                HStack(spacing: 8) {
                    if game.isLinked {
                        Label(game.cloudFile ?? "", systemImage: "link")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if game.needsManualMatch {
                        Label("Needs Match", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("No match found", systemImage: "questionmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if game.matchConfidence > 0 && game.matchConfidence < 1 {
                        Text("\(Int(game.matchConfidence * 100))% match")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Action button
            if game.needsManualMatch {
                Button {
                    onMatchRequested()
                } label: {
                    Label("Match", systemImage: "link.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if game.isLinked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var systemIcon: String {
        switch game.system {
        case .ds: return "gamecontroller"
        case .gba: return "gamecontroller.fill"
        case .gbc: return "gamecontroller"
        }
    }
    
    private var systemColor: Color {
        switch game.system {
        case .ds: return .blue
        case .gba: return .green
        case .gbc: return .purple
        }
    }
}

struct MatchSheetView: View {
    let game: DiscoveredGame
    let unmatchedCloudFiles: [String]
    @Binding var selectedCloudFile: String
    let onMatch: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Match \"\(game.displayName)\"")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select a cloud file to link with this game")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                if unmatchedCloudFiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cloud.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No unmatched cloud files found")
                            .font(.headline)
                        
                        Text("All cloud files are already linked to games")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Cloud Files")
                            .font(.headline)
                        
                        Picker("Select Cloud File", selection: $selectedCloudFile) {
                            ForEach(unmatchedCloudFiles, id: \.self) { fileName in
                                Text(fileName)
                                    .tag(fileName)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        
                        Text("This mapping will be saved permanently")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create Link") {
                        onMatch(selectedCloudFile)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(unmatchedCloudFiles.isEmpty)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .padding()
            .frame(width: 500, height: 400)
        }
    }
}

#Preview {
    NewContentView()
        .environmentObject(SyncManager())
        .environmentObject(SettingsManager())
        .environmentObject(GameMappingManager())
}