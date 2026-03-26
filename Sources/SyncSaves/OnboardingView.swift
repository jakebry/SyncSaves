import SwiftUI
import SyncSavesCore

struct OnboardingView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var gameMappingManager: GameMappingManager
    @EnvironmentObject var syncManager: SyncManager
    
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var currentStep = 0
    @State private var isImportingOpenEmu = false
    @State private var isImportingCloud = false
    @State private var showModded3DS = false
    @State private var threeDSIPAddress = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Focus state for TextField
    @FocusState private var focusedField: Field?
    
    private let totalSteps = 3
    
    enum Field {
        case threeDSIPAddress
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress indicator
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // Content area
            VStack(spacing: 20) {
                switch currentStep {
                case 0:
                    step1View
                case 1:
                    step2View
                case 2:
                    step3View
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < totalSteps - 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                } else {
                    Button("Finish Setup") {
                        completeSetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 500, height: 400)
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: showModded3DS) { oldValue, newValue in
            if newValue {
                // Focus the TextField when toggle is turned on
                focusedField = .threeDSIPAddress
            }
        }
        .onChange(of: currentStep) { oldStep, newStep in
            if newStep == 2 && showModded3DS {
                // Focus the TextField when we reach step 3 and toggle is on
                focusedField = .threeDSIPAddress
            }
        }
    }
    
    private var step1View: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Where does your Mac save games?")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Check if we have auto-detected paths
            let autoDetectedPaths = SettingsManager.autoDetectOpenEmuPaths()
            let hasAutoDetectedDS = !autoDetectedPaths.ds.isEmpty
            let hasAutoDetectedGBA = !autoDetectedPaths.gba.isEmpty
            let hasAutoDetectedGBC = !autoDetectedPaths.gbc.isEmpty
            let hasAnyAutoDetected = hasAutoDetectedDS || hasAutoDetectedGBA || hasAutoDetectedGBC
            
            if hasAnyAutoDetected {
                Text("OpenEmu save directories auto-detected!")
                    .font(.body)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 12) {
                    if hasAutoDetectedDS {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DS: \(URL(fileURLWithPath: autoDetectedPaths.ds).lastPathComponent)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text(autoDetectedPaths.ds)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text("Auto-detected")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    if hasAutoDetectedGBA {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GBA: \(URL(fileURLWithPath: autoDetectedPaths.gba).lastPathComponent)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text(autoDetectedPaths.gba)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text("Auto-detected")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    if hasAutoDetectedGBC {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GBC: \(URL(fileURLWithPath: autoDetectedPaths.gbc).lastPathComponent)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text(autoDetectedPaths.gbc)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text("Auto-detected")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 40)
                
                Text("If these paths look correct, click Next. Otherwise, browse manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Select your OpenEmu save directory")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                // Show current selected paths (if any)
                if !settings.openEmuDSPath.isEmpty && !hasAutoDetectedDS {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(settings.openEmuDSPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button {
                    isImportingOpenEmu = true
                } label: {
                    Label(hasAnyAutoDetected ? "Browse Manually" : "Select OpenEmu Directory", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .fileImporter(
                    isPresented: $isImportingOpenEmu,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    handleOpenEmuSelection(result)
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var step2View: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Where is your Cloud folder?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select your cloud sync directory (Dropbox, iCloud, etc.)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                if !settings.cloudDSPath.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(settings.cloudDSPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button {
                    isImportingCloud = true
                } label: {
                    Label("Select Cloud Directory", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .fileImporter(
                    isPresented: $isImportingCloud,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    handleCloudSelection(result)
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var step3View: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Do you play on a modded 3DS?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enable FTP sync for Nintendo DS games")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 20) {
                Toggle("Enable 3DS FTP Sync", isOn: $showModded3DS)
                    .toggleStyle(.switch)
                
                if showModded3DS {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3DS IP Address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("192.168.1.100", text: $threeDSIPAddress)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .threeDSIPAddress)
                        
                        Text("Make sure FTPD is running on your 3DS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            // Allow proceeding if any OpenEmu path is set (DS, GBA, or GBC)
            return !settings.openEmuDSPath.isEmpty || !settings.openEmuGBAPath.isEmpty || !settings.openEmuGBCPath.isEmpty
        case 1:
            return !settings.cloudDSPath.isEmpty
        case 2:
            if showModded3DS {
                return !threeDSIPAddress.isEmpty && threeDSIPAddress.range(of: #"^\d{1,3}(\.\d{1,3}){3}$"#, options: .regularExpression) != nil
            }
            return true
        default:
            return false
        }
    }
    
    private func handleOpenEmuSelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the selected directory"
                showError = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            let path = url.path
            
            // Check if this looks like a system-specific OpenEmu directory
            let lastPathComponent = url.lastPathComponent.lowercased()
            if lastPathComponent.contains("desmume") || lastPathComponent.contains("ds") {
                settings.openEmuDSPath = path
            } else if lastPathComponent.contains("visualboyadvance") || lastPathComponent.contains("gba") || lastPathComponent.contains("vba") {
                settings.openEmuGBAPath = path
            } else if lastPathComponent.contains("gambatte") || lastPathComponent.contains("gbc") || lastPathComponent.contains("gb") {
                settings.openEmuGBCPath = path
            } else {
                // Generic directory - set all paths
                settings.openEmuDSPath = path
                settings.openEmuGBAPath = path
                settings.openEmuGBCPath = path
            }
            
        } catch {
            errorMessage = "Failed to select directory: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func handleCloudSelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the selected directory"
                showError = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            let path = url.path
            settings.cloudDSPath = path
            settings.cloudGBAPath = path
            settings.cloudGBCPath = path
            
        } catch {
            errorMessage = "Failed to select directory: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func completeSetup() {
        isLoading = true
        
        // Save FTP settings if enabled
        if showModded3DS {
            settings.ftpHost = threeDSIPAddress
            settings.ftpPort = 5000 // Default FTPD port
            settings.ftpUsername = "anonymous"
            settings.ftpPassword = ""
        }
        
        // Perform initial scan to auto-link files
        Task {
            await performInitialScan()
            
            await MainActor.run {
                hasCompletedSetup = true
                isLoading = false
            }
        }
    }
    
    private func performInitialScan() async {
        let fileScanner = FileScanner()
        let scanResults = fileScanner.scanAllDirectories(using: settings)
        
        // Auto-link files based on fuzzy matching
        for (system, (openEmuFiles, cloudFiles)) in scanResults {
            let suggestions = fileScanner.findSuggestedMappings(
                openEmuFiles: openEmuFiles,
                cloudFiles: cloudFiles,
                for: system
            )
            
            // Add high-confidence matches (score > 0.7)
            for suggestion in suggestions where suggestion.score > 0.7 {
                let mapping = GameMapping(
                    openEmuFileName: suggestion.openEmuFile,
                    cloudFileName: suggestion.cloudFile
                )
                gameMappingManager.addMapping(mapping)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SettingsManager())
        .environmentObject(GameMappingManager())
        .environmentObject(SyncManager())
}