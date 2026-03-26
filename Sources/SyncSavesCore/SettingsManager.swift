import Foundation
import Combine

public class SettingsManager: ObservableObject {
    public static let pathsDidChangeNotification = Notification.Name("SettingsManager.pathsDidChange")
    @Published public var selectedSystem: GameSystem {
        didSet { UserDefaults.standard.set(selectedSystem.rawValue, forKey: Constants.selectedSystemKey) }
    }
    
    // Game names for each system
    @Published public var dsGameName: String {
        didSet { UserDefaults.standard.set(dsGameName, forKey: Constants.dsGameNameKey) }
    }
    
    @Published public var gbaGameName: String {
        didSet { UserDefaults.standard.set(gbaGameName, forKey: Constants.gbaGameNameKey) }
    }
    
    @Published public var gbcGameName: String {
        didSet { UserDefaults.standard.set(gbcGameName, forKey: Constants.gbcGameNameKey) }
    }
    
    // OpenEmu paths
    @Published public var openEmuDSPath: String {
        didSet { UserDefaults.standard.set(openEmuDSPath, forKey: Constants.openEmuDSPathKey) }
    }
    
    @Published public var openEmuGBAPath: String {
        didSet { UserDefaults.standard.set(openEmuGBAPath, forKey: Constants.openEmuGBAPathKey) }
    }
    
    @Published public var openEmuGBCPath: String {
        didSet { UserDefaults.standard.set(openEmuGBCPath, forKey: Constants.openEmuGBCPathKey) }
    }
    
    // Cloud paths
    @Published public var cloudDSPath: String {
        didSet { UserDefaults.standard.set(cloudDSPath, forKey: Constants.cloudDSPathKey) }
    }
    
    @Published public var cloudGBAPath: String {
        didSet { UserDefaults.standard.set(cloudGBAPath, forKey: Constants.cloudGBAPathKey) }
    }
    
    @Published public var cloudGBCPath: String {
        didSet { UserDefaults.standard.set(cloudGBCPath, forKey: Constants.cloudGBCPathKey) }
    }
    
    // FTP settings (primarily for DS)
    @Published public var ftpHost: String {
        didSet { UserDefaults.standard.set(ftpHost, forKey: Constants.ftpHostKey) }
    }
    
    @Published public var ftpPort: Int {
        didSet { UserDefaults.standard.set(ftpPort, forKey: Constants.ftpPortKey) }
    }
    
    @Published public var ftpUsername: String {
        didSet { UserDefaults.standard.set(ftpUsername, forKey: Constants.ftpUsernameKey) }
    }
    
    @Published public var ftpPassword: String {
        didSet { UserDefaults.standard.set(ftpPassword, forKey: Constants.ftpPasswordKey) }
    }
    
    // Computed properties
    public var currentGameName: String {
        switch selectedSystem {
        case .ds: return dsGameName
        case .gba: return gbaGameName
        case .gbc: return gbcGameName
        }
    }
    
    public var currentOpenEmuPath: String {
        switch selectedSystem {
        case .ds: return openEmuDSPath
        case .gba: return openEmuGBAPath
        case .gbc: return openEmuGBCPath
        }
    }
    
    public var currentCloudPath: String {
        switch selectedSystem {
        case .ds: return cloudDSPath
        case .gba: return cloudGBAPath
        case .gbc: return cloudGBCPath
        }
    }
    
    public var isConfigured: Bool {
        switch selectedSystem {
        case .ds:
            return !openEmuDSPath.isEmpty && !cloudDSPath.isEmpty && !ftpHost.isEmpty
        case .gba:
            return !openEmuGBAPath.isEmpty && !cloudGBAPath.isEmpty
        case .gbc:
            return !openEmuGBCPath.isEmpty && !cloudGBCPath.isEmpty
        }
    }
    
    public init() {
        // Load from UserDefaults or set defaults
        if let systemRaw = UserDefaults.standard.string(forKey: Constants.selectedSystemKey),
           let system = GameSystem(rawValue: systemRaw) {
            self.selectedSystem = system
        } else {
            self.selectedSystem = .ds
        }
        
        self.dsGameName = UserDefaults.standard.string(forKey: Constants.dsGameNameKey) ?? "ds_game"
        self.gbaGameName = UserDefaults.standard.string(forKey: Constants.gbaGameNameKey) ?? "gba_game"
        self.gbcGameName = UserDefaults.standard.string(forKey: Constants.gbcGameNameKey) ?? "gbc_game"
        
        // Try to auto-detect OpenEmu paths first
        let autoDetectedPaths = Self.autoDetectOpenEmuPaths()
        
        // Load saved paths or use auto-detected ones
        self.openEmuDSPath = UserDefaults.standard.string(forKey: Constants.openEmuDSPathKey) ?? autoDetectedPaths.ds
        self.openEmuGBAPath = UserDefaults.standard.string(forKey: Constants.openEmuGBAPathKey) ?? autoDetectedPaths.gba
        self.openEmuGBCPath = UserDefaults.standard.string(forKey: Constants.openEmuGBCPathKey) ?? autoDetectedPaths.gbc
        
        self.cloudDSPath = UserDefaults.standard.string(forKey: Constants.cloudDSPathKey) ?? ""
        self.cloudGBAPath = UserDefaults.standard.string(forKey: Constants.cloudGBAPathKey) ?? ""
        self.cloudGBCPath = UserDefaults.standard.string(forKey: Constants.cloudGBCPathKey) ?? ""
        
        self.ftpHost = UserDefaults.standard.string(forKey: Constants.ftpHostKey) ?? ""
        let storedPort = UserDefaults.standard.integer(forKey: Constants.ftpPortKey)
        self.ftpPort = storedPort == 0 ? Constants.defaultFTPPort : storedPort
        self.ftpUsername = UserDefaults.standard.string(forKey: Constants.ftpUsernameKey) ?? ""
        self.ftpPassword = UserDefaults.standard.string(forKey: Constants.ftpPasswordKey) ?? ""
    }
    
    public func resetToDefaults() {
        selectedSystem = .ds
        dsGameName = "ds_game"
        gbaGameName = "gba_game"
        gbcGameName = "gbc_game"
        openEmuDSPath = ""
        openEmuGBAPath = ""
        openEmuGBCPath = ""
        cloudDSPath = ""
        cloudGBAPath = ""
        cloudGBCPath = ""
        ftpHost = ""
        ftpPort = Constants.defaultFTPPort
        ftpUsername = ""
        ftpPassword = ""
    }
    
    // Helper methods to get file URLs for current system
    func openEmuSaveURL() -> URL? {
        guard !currentOpenEmuPath.isEmpty, !currentGameName.isEmpty else { return nil }
        let path = (currentOpenEmuPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path).appendingPathComponent("\(currentGameName).\(selectedSystem.openEmuExtension)")
    }
    
    func cloudSaveURL() -> URL? {
        guard !currentCloudPath.isEmpty, !currentGameName.isEmpty else { return nil }
        let path = (currentCloudPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path).appendingPathComponent("\(currentGameName).\(selectedSystem.cloudExtension)")
    }
    
    // Helper methods to get base directory URLs (without filename)
    func openEmuBaseURL() -> URL? {
        guard !currentOpenEmuPath.isEmpty else { return nil }
        let path = (currentOpenEmuPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }
    
    func cloudBaseURL() -> URL? {
        guard !currentCloudPath.isEmpty else { return nil }
        let path = (currentCloudPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }
    
    func threeDSSavePath() -> String {
        // Only for DS system
        guard selectedSystem == .ds else { return "" }
        return "/\(currentGameName).\(selectedSystem.cloudExtension)"
    }
    
    // Helper to get all configured systems
    public var configuredSystems: [GameSystem] {
        var systems: [GameSystem] = []
        
        if !openEmuDSPath.isEmpty && !cloudDSPath.isEmpty {
            systems.append(.ds)
        }
        
        if !openEmuGBAPath.isEmpty && !cloudGBAPath.isEmpty {
            systems.append(.gba)
        }
        
        if !openEmuGBCPath.isEmpty && !cloudGBCPath.isEmpty {
            systems.append(.gbc)
        }
        
        return systems
    }
    

    
    // MARK: - Auto-detection
    
    /// Auto-detects OpenEmu save paths for DS, GBA, and GBC systems
    public static func autoDetectOpenEmuPaths() -> (ds: String, gba: String, gbc: String) {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        
        // Base OpenEmu application support directory
        let openEmuBase = homeDirectory.appendingPathComponent("Library/Application Support/OpenEmu")
        
        // Default paths for each system
        let dsPath = openEmuBase.appendingPathComponent("DeSmuME/Battery Saves")
        let gbaPath = openEmuBase.appendingPathComponent("VisualBoyAdvance/Battery Saves")
        let gbcPath = openEmuBase.appendingPathComponent("Gambatte/Battery Saves")
        
        // Check if paths exist and return them
        var detectedDS = ""
        var detectedGBA = ""
        var detectedGBC = ""
        
        if fileManager.fileExists(atPath: dsPath.path) {
            detectedDS = dsPath.path
        }
        
        if fileManager.fileExists(atPath: gbaPath.path) {
            detectedGBA = gbaPath.path
        }
        
        if fileManager.fileExists(atPath: gbcPath.path) {
            detectedGBC = gbcPath.path
        }
        
        return (detectedDS, detectedGBA, detectedGBC)
    }
    
    /// Checks if OpenEmu paths were auto-detected (not manually set by user)
    public var hasAutoDetectedOpenEmuPaths: Bool {
        let autoDetected = Self.autoDetectOpenEmuPaths()
        
        // Check if current paths match auto-detected paths
        let dsAutoDetected = !autoDetected.ds.isEmpty && openEmuDSPath == autoDetected.ds
        let gbaAutoDetected = !autoDetected.gba.isEmpty && openEmuGBAPath == autoDetected.gba
        let gbcAutoDetected = !autoDetected.gbc.isEmpty && openEmuGBCPath == autoDetected.gbc
        
        return dsAutoDetected || gbaAutoDetected || gbcAutoDetected
    }
}