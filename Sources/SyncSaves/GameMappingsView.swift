import SwiftUI
import SyncSavesCore

struct GameMappingsView: View {
    @EnvironmentObject var gameMappingManager: GameMappingManager
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var fileScanner = FileScanner()
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var mappingToDelete: GameMapping?
    @State private var scanResults: [GameSystem: (openEmuFiles: [String], cloudFiles: [String])] = [:]
    @State private var isLoading = false
    @State private var scanError: String?
    
    var filteredMappings: [GameMapping] {
        if searchText.isEmpty {
            return gameMappingManager.mappings
        } else {
            return gameMappingManager.mappings.filter { mapping in
                mapping.openEmuFileName.localizedCaseInsensitiveContains(searchText) ||
                mapping.cloudFileName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scan status and controls
                VStack(spacing: 12) {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Scanning directories...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let error = scanError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else {
                        HStack {
                            Text("\(gameMappingManager.mappings.count) mappings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Rescan Directories") {
                                scanDirectories()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.05))
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search mappings...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                
                // Mappings list or empty state
                if filteredMappings.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "link")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            VStack(spacing: 12) {
                                Text("No Game Mappings")
                                    .font(.headline)
                                Text("Game mappings link OpenEmu save files to their Cloud counterparts.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button("Add First Mapping") {
                                    showingAddSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 8)
                            }
                        } else {
                            Text("No matches for \"\(searchText)\"")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredMappings) { mapping in
                            MappingRow(mapping: mapping) {
                                mappingToDelete = mapping
                                showingDeleteAlert = true
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                
                // Bottom toolbar
                HStack {
                    if !filteredMappings.isEmpty {
                        Button("Clear All") {
                            gameMappingManager.clearAll()
                        }
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button("Add") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
            }
            .navigationTitle("Game Mappings")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if !os(macOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
            .alert("Delete Mapping", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let mapping = mappingToDelete {
                        gameMappingManager.removeMapping(withId: mapping.id)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this mapping?")
            }
            .sheet(isPresented: $showingAddSheet) {
                AddMappingView(fileScanner: fileScanner, scanResults: scanResults)
                    .environmentObject(gameMappingManager)
                    .environmentObject(settings)
            }
            .onAppear {
                scanDirectories()
            }
        }
    }
    
    private func scanDirectories() {
        isLoading = true
        scanError = nil
        
        Task {
            let results = fileScanner.scanAllDirectories(using: settings)
            await MainActor.run {
                scanResults = results
                isLoading = false
                
                if results.isEmpty {
                    scanError = "No save files found in configured directories"
                }
            }
        }
    }
}

struct MappingRow: View {
    let mapping: GameMapping
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(mapping.openEmuFileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(mapping.cloudFileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

struct AddMappingView: View {
    @EnvironmentObject var gameMappingManager: GameMappingManager
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    let fileScanner: FileScanner
    let scanResults: [GameSystem: (openEmuFiles: [String], cloudFiles: [String])]
    
    @State private var selectedSystem: GameSystem = .ds
    @State private var selectedOpenEmuFile = ""
    @State private var selectedCloudFile = ""
    @State private var suggestions: [(openEmuFile: String, cloudFile: String, score: Double)] = []
    
    var openEmuFiles: [String] {
        scanResults[selectedSystem]?.openEmuFiles ?? []
    }
    
    var cloudFiles: [String] {
        scanResults[selectedSystem]?.cloudFiles ?? []
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("System") {
                    Picker("System", selection: $selectedSystem) {
                        ForEach(GameSystem.allCases) { system in
                            Text(system.displayName)
                                .tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedSystem) {
                        updateSuggestions()
                        selectedOpenEmuFile = ""
                        selectedCloudFile = ""
                    }
                }
                
                Section("OpenEmu File") {
                    if openEmuFiles.isEmpty {
                        Text("No \(selectedSystem.displayName) files found in OpenEmu directory")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Picker("Select OpenEmu File", selection: $selectedOpenEmuFile) {
                            Text("Select a file...")
                                .tag("")
                            ForEach(openEmuFiles, id: \.self) { file in
                                Text(file)
                                    .tag(file)
                            }
                        }
                        .onChange(of: selectedOpenEmuFile) {
                            updateSuggestions()
                        }
                    }
                }
                
                Section("Cloud File") {
                    if cloudFiles.isEmpty {
                        Text("No \(selectedSystem.displayName) files found in Cloud directory")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Picker("Select Cloud File", selection: $selectedCloudFile) {
                            Text("Select a file...")
                                .tag("")
                            ForEach(cloudFiles, id: \.self) { file in
                                Text(file)
                                    .tag(file)
                            }
                        }
                    }
                }
                
                if !suggestions.isEmpty {
                    Section("Suggested Matches") {
                        ForEach(suggestions.prefix(3), id: \.openEmuFile) { suggestion in
                            Button {
                                selectedOpenEmuFile = suggestion.openEmuFile
                                selectedCloudFile = suggestion.cloudFile
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(suggestion.openEmuFile)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Text(String(format: "%.0f%%", suggestion.score * 100))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("→ \(suggestion.cloudFile)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Section("Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SyncSaves synchronizes save files between:")
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• OpenEmu (macOS emulator)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Cloud folder (for Delta iOS)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Modded 3DS via FTP (DS only)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Mapping")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMapping()
                    }
                    .disabled(selectedOpenEmuFile.isEmpty || selectedCloudFile.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            updateSuggestions()
        }
    }
    
    private func updateSuggestions() {
        guard !openEmuFiles.isEmpty && !cloudFiles.isEmpty else {
            suggestions = []
            return
        }
        
        suggestions = fileScanner.findSuggestedMappings(
            openEmuFiles: openEmuFiles,
            cloudFiles: cloudFiles,
            for: selectedSystem
        )
    }
    
    private func addMapping() {
        let mapping = GameMapping(
            openEmuFileName: selectedOpenEmuFile,
            cloudFileName: selectedCloudFile
        )
        gameMappingManager.addMapping(mapping)
        dismiss()
    }
}

#Preview {
    GameMappingsView()
        .environmentObject(GameMappingManager())
        .environmentObject(SettingsManager())
}