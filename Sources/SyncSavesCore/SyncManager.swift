import Foundation
import Combine

public class SyncManager: ObservableObject {
    private let fileManager = FileManager.default
    private var ftpClient: FTPClient?
    private let gameMappingManager = GameMappingManager()
    
    @Published public var isSyncing = false
    @Published public var lastSyncResults: [SyncResult] = []
    
    public init() {}
    
    // Sync for a specific system
    public func performSync(for system: GameSystem? = nil) async throws {
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let settings = SettingsManager()
        let systemsToSync = system.map { [$0] } ?? settings.configuredSystems
        
        guard !systemsToSync.isEmpty else {
            throw SyncError.pathNotConfigured("No systems configured for sync")
        }
        
        var results: [SyncResult] = []
        
        for system in systemsToSync {
            settings.selectedSystem = system
            let result = try await performSystemSync(settings: settings)
            results.append(result)
        }
        
        lastSyncResults = results
    }
    
    private func performSystemSync(settings: SettingsManager) async throws -> SyncResult {
        let system = settings.selectedSystem
        
        // Check if all paths are configured for this system
        guard let openEmuURL = settings.openEmuSaveURL(),
              let cloudURL = settings.cloudSaveURL() else {
            throw SyncError.pathNotConfigured("Paths not configured for \(system.displayName)")
        }
        
        // Apply file name translation using game mappings
        let translatedOpenEmuURL = applyFileNameTranslation(to: openEmuURL, for: system, from: .openEmu, to: .cloud)
        let translatedCloudURL = applyFileNameTranslation(to: cloudURL, for: system, from: .cloud, to: .openEmu)
        
        // Collect all save files with their modification dates
        var saveFiles: [SaveFile] = []
        
        // Check OpenEmu file (using translated name if mapping exists)
        if let openEmuFile = await getSaveFile(at: translatedOpenEmuURL, system: system, location: .openEmu) {
            saveFiles.append(openEmuFile)
        }
        
        // Check Cloud file (using translated name if mapping exists)
        if let cloudFile = await getSaveFile(at: translatedCloudURL, system: system, location: .cloud) {
            saveFiles.append(cloudFile)
        }
        
        // Check 3DS file via FTP (only for DS)
        if system == .ds, let threeDSFile = try? await get3DSSaveFile(settings: settings) {
            saveFiles.append(threeDSFile)
        }
        
        guard !saveFiles.isEmpty else {
            throw SyncError.fileNotFound("No save files found for \(system.displayName)")
        }
        
        // Find the newest file
        guard let newestFile = saveFiles.max(by: { $0.modifiedDate < $1.modifiedDate }) else {
            throw SyncError.fileOperationFailed("Could not determine newest file for \(system.displayName)")
        }
        
        // Perform sync based on system and file type
        if system.requiresFooterStripping {
            // DS system with footer handling
            try await handleDSSync(newestFile, settings: settings)
        } else {
            // GBA/GBC - straightforward copy
            try await handleSimpleSync(newestFile, settings: settings)
        }
        
        // Update all locations to newest state
        try await updateAllLocations(with: newestFile, settings: settings)
        
        return SyncResult(
            success: true,
            message: "Successfully synchronized \(system.displayName) saves",
            timestamp: Date(),
            filesSynced: saveFiles,
            system: system
        )
    }
    
    private func getSaveFile(at url: URL, system: GameSystem, location: FileLocation) async -> SaveFile? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let modifiedDate = attributes[.modificationDate] as? Date {
                return SaveFile(path: url, modifiedDate: modifiedDate, system: system, location: location)
            }
        } catch {
            print("Could not read file at \(url.path): \(error)")
        }
        return nil
    }
    
    /// Apply file name translation based on game mappings
    private func applyFileNameTranslation(to url: URL, for system: GameSystem, from source: FileLocation, to target: FileLocation) -> URL {
        let fileName = url.lastPathComponent
        let translatedFileName = gameMappingManager.translateFileName(fileName, from: source, to: target)
        
        if translatedFileName != fileName {
            // Return new URL with translated file name
            return url.deletingLastPathComponent().appendingPathComponent(translatedFileName)
        }
        
        return url
    }
    
    /// Sync file with name translation applied
    private func syncFileWithTranslation(sourceURL: URL, destinationURL: URL, system: GameSystem) async throws {
        let data = try Data(contentsOf: sourceURL)
        
        // Apply file name translation if needed
        let translatedDestinationURL = applyFileNameTranslation(
            to: destinationURL,
            for: system,
            from: sourceURL == sourceURL ? .openEmu : .cloud,
            to: destinationURL == destinationURL ? .cloud : .openEmu
        )
        
        try data.write(to: translatedDestinationURL)
    }
    
    private func get3DSSaveFile(settings: SettingsManager) async throws -> SaveFile {
        // Only for DS system
        guard settings.selectedSystem == .ds else {
            throw SyncError.unsupportedSystem("3DS sync only supported for DS")
        }
        
        // Initialize FTP client
        ftpClient = FTPClient(
            host: settings.ftpHost,
            port: settings.ftpPort,
            username: settings.ftpUsername,
            password: settings.ftpPassword
        )
        
        guard let client = ftpClient else {
            throw SyncError.ftpConnectionFailed("Could not initialize FTP client")
        }
        
        do {
            try await client.connect()
            let remotePath = settings.threeDSSavePath()
            let modifiedDate = try await client.getModificationDate(for: remotePath)
            
            // Create a temporary URL for the file
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(settings.currentGameName)_3ds.\(settings.selectedSystem.fileExtension)")
            
            return SaveFile(
                path: tempURL,
                modifiedDate: modifiedDate,
                system: .ds,
                location: .threeDS
            )
        } catch {
            throw SyncError.ftpConnectionFailed("FTP error: \(error.localizedDescription)")
        }
    }
    
    private func handleDSSync(_ newestFile: SaveFile, settings: SettingsManager) async throws {
        switch newestFile.location {
        case .openEmu:
            // OpenEmu .dsv → strip footer → .sav
            try await syncFromOpenEmu(newestFile, settings: settings)
        case .cloud, .threeDS:
            // .sav → read existing OpenEmu footer → append → .dsv
            try await syncToOpenEmu(newestFile, settings: settings)
        }
    }
    
    private func handleSimpleSync(_ newestFile: SaveFile, settings: SettingsManager) async throws {
        // For GBA/GBC, just copy the newest file to other locations with name translation
        let data = try Data(contentsOf: newestFile.path)
        
        // Copy to all other locations with name translation
        if newestFile.location != .openEmu, let openEmuURL = settings.openEmuSaveURL() {
            let translatedOpenEmuURL = applyFileNameTranslation(
                to: openEmuURL,
                for: settings.selectedSystem,
                from: newestFile.location == .cloud ? .cloud : .threeDS,
                to: .openEmu
            )
            try data.write(to: translatedOpenEmuURL)
        }
        
        if newestFile.location != .cloud, let cloudURL = settings.cloudSaveURL() {
            let translatedCloudURL = applyFileNameTranslation(
                to: cloudURL,
                for: settings.selectedSystem,
                from: newestFile.location == .openEmu ? .openEmu : .threeDS,
                to: .cloud
            )
            try data.write(to: translatedCloudURL)
        }
        
        // Note: 3DS sync not supported for GBA/GBC
    }
    
    private func syncFromOpenEmu(_ openEmuFile: SaveFile, settings: SettingsManager) async throws {
        // OpenEmu .dsv → strip footer → .sav
        let dsvData = try Data(contentsOf: openEmuFile.path)
        
        guard dsvData.count > Constants.desmumeFooterSize else {
            throw SyncError.invalidSaveFile("DSV file too small to contain footer")
        }
        
        // Strip the last 122 bytes (DeSmuME footer)
        let savData = dsvData.prefix(dsvData.count - Constants.desmumeFooterSize)
        
        // Save to cloud with name translation
        if let cloudURL = settings.cloudSaveURL() {
            let translatedCloudURL = applyFileNameTranslation(
                to: cloudURL,
                for: settings.selectedSystem,
                from: .openEmu,
                to: .cloud
            )
            try savData.write(to: translatedCloudURL)
        }
        
        // Upload to 3DS via FTP
        try await uploadTo3DS(data: savData, settings: settings)
    }
    
    private func syncToOpenEmu(_ savFile: SaveFile, settings: SettingsManager) async throws {
        // .sav → read existing OpenEmu footer → append → .dsv
        
        // Read the .sav data
        let savData = try Data(contentsOf: savFile.path)
        
        // Get existing OpenEmu .dsv to extract its footer (with name translation)
        guard let openEmuURL = settings.openEmuSaveURL() else {
            throw SyncError.pathNotConfigured("OpenEmu path not configured")
        }
        
        let translatedOpenEmuURL = applyFileNameTranslation(
            to: openEmuURL,
            for: settings.selectedSystem,
            from: savFile.location,
            to: .openEmu
        )
        
        if fileManager.fileExists(atPath: translatedOpenEmuURL.path) {
            // Extract footer from existing .dsv
            let existingDSVData = try Data(contentsOf: translatedOpenEmuURL)
            
            guard existingDSVData.count >= Constants.desmumeFooterSize else {
                throw SyncError.invalidSaveFile("Existing DSV file too small")
            }
            
            // Extract the last 122 bytes as footer
            let footer = existingDSVData.suffix(Constants.desmumeFooterSize)
            
            // Create new .dsv with .sav data + existing footer
            let newDSVData = savData + footer
            try newDSVData.write(to: translatedOpenEmuURL)
        } else {
            // If no existing .dsv, create one with empty footer
            let emptyFooter = Data(count: Constants.desmumeFooterSize)
            let dsvData = savData + emptyFooter
            try dsvData.write(to: translatedOpenEmuURL)
        }
    }
    
    private func updateAllLocations(with newestFile: SaveFile, settings: SettingsManager) async throws {
        let system = settings.selectedSystem
        
        if system.requiresFooterStripping {
            // DS system
            switch newestFile.location {
            case .openEmu:
                // Already handled in syncFromOpenEmu
                break
            case .cloud:
                // Copy to other locations with name translation
                let data = try Data(contentsOf: newestFile.path)
                
                // Update OpenEmu with name translation
                try await syncToOpenEmu(newestFile, settings: settings)
                
                // Upload to 3DS
                try await uploadTo3DS(data: data, settings: settings)
                
            case .threeDS:
                // Download from 3DS and update other locations
                let data = try await downloadFrom3DS(settings: settings)
                
                // Save to cloud with name translation
                if let cloudURL = settings.cloudSaveURL() {
                    let translatedCloudURL = applyFileNameTranslation(
                        to: cloudURL,
                        for: system,
                        from: .threeDS,
                        to: .cloud
                    )
                    try data.write(to: translatedCloudURL)
                }
                
                // Update OpenEmu with name translation
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("temp_3ds.sav")
                try data.write(to: tempURL)
                let tempFile = SaveFile(path: tempURL, modifiedDate: Date(), system: .ds, location: .threeDS)
                try await syncToOpenEmu(tempFile, settings: settings)
            }
        } else {
            // GBA/GBC - already handled in handleSimpleSync
        }
    }
    
    private func uploadTo3DS(data: Data, settings: SettingsManager) async throws {
        guard settings.selectedSystem == .ds else { return }
        
        guard let client = ftpClient ?? FTPClient(
            host: settings.ftpHost,
            port: settings.ftpPort,
            username: settings.ftpUsername,
            password: settings.ftpPassword
        ) else {
            throw SyncError.ftpConnectionFailed("FTP client not available")
        }
        
        try await client.connect()
        let remotePath = settings.threeDSSavePath()
        
        // Create temporary file
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("upload_temp.sav")
        try data.write(to: tempURL)
        
        try await client.upload(file: tempURL.path, to: remotePath)
        
        // Clean up
        try? fileManager.removeItem(at: tempURL)
    }
    
    private func downloadFrom3DS(settings: SettingsManager) async throws -> Data {
        guard settings.selectedSystem == .ds else {
            throw SyncError.unsupportedSystem("3DS download only for DS")
        }
        
        guard let client = ftpClient ?? FTPClient(
            host: settings.ftpHost,
            port: settings.ftpPort,
            username: settings.ftpUsername,
            password: settings.ftpPassword
        ) else {
            throw SyncError.ftpConnectionFailed("FTP client not available")
        }
        
        try await client.connect()
        let remotePath = settings.threeDSSavePath()
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("download_temp.sav")
        
        try await client.download(from: remotePath, to: tempURL.path)
        
        let data = try Data(contentsOf: tempURL)
        try? fileManager.removeItem(at: tempURL)
        
        return data
    }
}

// Simple FTP client (placeholder)
public class FTPClient {
    let host: String
    let port: Int
    let username: String
    let password: String
    
    public init?(host: String, port: Int, username: String, password: String) {
        guard !host.isEmpty else { return nil }
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }
    
    func connect() async throws {
        // Implementation would use a real FTP library
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    func getModificationDate(for path: String) async throws -> Date {
        return Date()
    }
    
    func upload(file localPath: String, to remotePath: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    func download(from remotePath: String, to localPath: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}