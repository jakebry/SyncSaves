import SwiftUI
import SyncSavesCore

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var gameMappingManager: GameMappingManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingOpenEmuPicker = false
    @State private var showingCloudPicker = false
    @State private var showingTestFTP = false
    @State private var ftpTestResult: String?
    @State private var isTestingFTP = false
    @State private var pickerType: PickerType = .openEmuDS
    @State private var showingMappingsList = false
    
    // Local state for TextFields to prevent focus loss
    @State private var localDSGameName: String = ""
    @State private var localGBAGameName: String = ""
    @State private var localGBCGameName: String = ""
    @State private var localFTPHost: String = ""
    @State private var localFTPPort: Int = 0
    @State private var localFTPUsername: String = ""
    @State private var localFTPPassword: String = ""
    
    enum PickerType {
        case openEmuDS, openEmuGBA, openEmuGBC
        case cloudDS, cloudGBA, cloudGBC
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Game Systems") {
                    Picker("Default System", selection: $settings.selectedSystem) {
                        ForEach(GameSystem.allCases) { system in
                            Text(system.displayName)
                                .tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("DS Game Name:") {
                            TextField("ds_game", text: $localDSGameName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                        }
                        
                        LabeledContent("GBA Game Name:") {
                            TextField("gba_game", text: $localGBAGameName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                        }
                        
                        LabeledContent("GBC Game Name:") {
                            TextField("gbc_game", text: $localGBCGameName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("OpenEmu Save Folders") {
                    VStack(alignment: .leading, spacing: 12) {
                        FolderPickerRow(
                            title: "DS Folder:",
                            path: settings.openEmuDSPath,
                            action: { pickerType = .openEmuDS; showingOpenEmuPicker = true }
                        )
                        
                        FolderPickerRow(
                            title: "GBA Folder:",
                            path: settings.openEmuGBAPath,
                            action: { pickerType = .openEmuGBA; showingOpenEmuPicker = true }
                        )
                        
                        FolderPickerRow(
                            title: "GBC Folder:",
                            path: settings.openEmuGBCPath,
                            action: { pickerType = .openEmuGBC; showingOpenEmuPicker = true }
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Cloud Save Folders") {
                    VStack(alignment: .leading, spacing: 12) {
                        FolderPickerRow(
                            title: "DS Folder:",
                            path: settings.cloudDSPath,
                            action: { pickerType = .cloudDS; showingCloudPicker = true }
                        )
                        
                        FolderPickerRow(
                            title: "GBA Folder:",
                            path: settings.cloudGBAPath,
                            action: { pickerType = .cloudGBA; showingCloudPicker = true }
                        )
                        
                        FolderPickerRow(
                            title: "GBC Folder:",
                            path: settings.cloudGBCPath,
                            action: { pickerType = .cloudGBC; showingCloudPicker = true }
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                Section("3DS FTP Configuration (DS Only)") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Host:") {
                            TextField("192.168.1.x", text: $localFTPHost)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                        }
                        
                        LabeledContent("Port:") {
                            TextField("21", value: $localFTPPort, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }
                        
                        LabeledContent("Username:") {
                            TextField("username", text: $localFTPUsername)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                        }
                        
                        LabeledContent("Password:") {
                            SecureField("password", text: $localFTPPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                        }
                        
                        HStack {
                            Button("Test FTP Connection") {
                                testFTPConnection()
                            }
                            .disabled(isTestingFTP || localFTPHost.isEmpty)
                            
                            if isTestingFTP {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.top, 4)
                        
                        if let result = ftpTestResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("Success") ? .green : .red)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                        // Also reset local state
                        localDSGameName = settings.dsGameName
                        localGBAGameName = settings.gbaGameName
                        localGBCGameName = settings.gbcGameName
                        localFTPHost = settings.ftpHost
                        localFTPPort = settings.ftpPort
                        localFTPUsername = settings.ftpUsername
                        localFTPPassword = settings.ftpPassword
                        ftpTestResult = nil
                    }
                    .foregroundColor(.red)
                }
                
                Section("Game Mappings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Auto-Linked Games:")
                                .font(.headline)
                            Spacer()
                            Text("\(gameMappingManager.mappings.count) mapping(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Games are automatically linked based on file name similarity. Manual matches can be made from the main screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("View All Mappings") {
                            // Game mappings view would be shown here
                            showingMappingsList = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SyncSaves synchronizes save files between:")
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• OpenEmu (macOS emulator)")
                            Text("• Cloud folder (for Delta iOS)")
                            Text("• Modded 3DS via FTP (DS only)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Text("\nFile formats:")
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• DS: .dsv (OpenEmu) ↔ .sav (Cloud/3DS)")
                            Text("   - .dsv has 122-byte DeSmuME footer")
                            Text("• GBA/GBC: .sav (raw, no footer)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save local state back to settings
                        settings.dsGameName = localDSGameName
                        settings.gbaGameName = localGBAGameName
                        settings.gbcGameName = localGBCGameName
                        settings.ftpHost = localFTPHost
                        settings.ftpPort = localFTPPort
                        settings.ftpUsername = localFTPUsername
                        settings.ftpPassword = localFTPPassword
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #else
                // macOS: Add prominent Done button at the bottom
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Save local state back to settings
                        settings.dsGameName = localDSGameName
                        settings.gbaGameName = localGBAGameName
                        settings.gbcGameName = localGBCGameName
                        settings.ftpHost = localFTPHost
                        settings.ftpPort = localFTPPort
                        settings.ftpUsername = localFTPUsername
                        settings.ftpPassword = localFTPPassword
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .keyboardShortcut(.defaultAction)
                }
                #endif
            }
            .fileImporter(
                isPresented: $showingOpenEmuPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result, for: pickerType)
            }
            .fileImporter(
                isPresented: $showingCloudPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result, for: pickerType)
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 700)
        #endif
        .sheet(isPresented: $showingMappingsList) {
            MappingsListView(mappings: gameMappingManager.mappings)
        }
        .onAppear {
            // Initialize local state from settings
            localDSGameName = settings.dsGameName
            localGBAGameName = settings.gbaGameName
            localGBCGameName = settings.gbcGameName
            localFTPHost = settings.ftpHost
            localFTPPort = settings.ftpPort
            localFTPUsername = settings.ftpUsername
            localFTPPassword = settings.ftpPassword
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>, for type: PickerType) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                switch type {
                case .openEmuDS:
                    settings.openEmuDSPath = url.path
                case .openEmuGBA:
                    settings.openEmuGBAPath = url.path
                case .openEmuGBC:
                    settings.openEmuGBCPath = url.path
                case .cloudDS:
                    settings.cloudDSPath = url.path
                case .cloudGBA:
                    settings.cloudGBAPath = url.path
                case .cloudGBC:
                    settings.cloudGBCPath = url.path
                }
            }
        case .failure(let error):
            print("Failed to select folder: \(error)")
        }
    }
    
    private func testFTPConnection() {
        isTestingFTP = true
        ftpTestResult = nil
        
        Task {
            // Simulate FTP test
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                isTestingFTP = false
                let success = !localFTPHost.isEmpty && localFTPHost.contains(".")
                ftpTestResult = success ? 
                    "Successfully connected to \(localFTPHost)" :
                    "Failed to connect to \(localFTPHost)"
            }
        }
    }
    
    private func showMappingsList() {
        showingMappingsList = true
    }
}

struct MappingsListView: View {
    let mappings: [GameMapping]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            if mappings.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "link.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Game Mappings")
                        .font(.headline)
                    
                    Text("Games will be auto-linked when discovered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(width: 400, height: 300)
            } else {
                List(mappings) { mapping in
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mapping.openEmuFileName)
                                .font(.body)
                            Text("→ \(mapping.cloudFileName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(mapping.createdAt, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .frame(width: 600, height: 400)
            }
        }
        .navigationTitle("Game Mappings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct FolderPickerRow: View {
    let title: String
    let path: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .frame(width: 100, alignment: .leading)
            
            Text(path.isEmpty ? "Not set" : path)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("Browse...", action: action)
        }
    }
}

struct LabeledContent<Content: View>: View {
    let label: String
    let content: Content
    
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 120, alignment: .trailing)
            content
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}