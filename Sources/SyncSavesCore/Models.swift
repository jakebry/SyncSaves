import Foundation

public enum GameSystem: String, CaseIterable, Identifiable {
    case ds = "Nintendo DS"
    case gba = "Game Boy Advance"
    case gbc = "Game Boy Color"
    
    public var id: String { rawValue }
    
    public var fileExtension: String {
        switch self {
        case .ds: return "dsv"
        case .gba, .gbc: return "sav"
        }
    }
    
    public var requiresFooterStripping: Bool {
        self == .ds
    }
    
    public var footerSize: Int {
        self == .ds ? 122 : 0
    }
    
    public var displayName: String {
        switch self {
        case .ds: return "DS"
        case .gba: return "GBA"
        case .gbc: return "GBC"
        }
    }
}

public struct SaveFile: Identifiable {
    public let id = UUID()
    public let path: URL
    public let modifiedDate: Date
    public let system: GameSystem
    public let location: FileLocation
    
    public init(path: URL, modifiedDate: Date, system: GameSystem, location: FileLocation) {
        self.path = path
        self.modifiedDate = modifiedDate
        self.system = system
        self.location = location
    }
}

public struct SyncResult {
    public let success: Bool
    public let message: String
    public let timestamp: Date
    public let filesSynced: [SaveFile]
    public let system: GameSystem
    
    public init(success: Bool, message: String, timestamp: Date = Date(), filesSynced: [SaveFile] = [], system: GameSystem) {
        self.success = success
        self.message = message
        self.timestamp = timestamp
        self.filesSynced = filesSynced
        self.system = system
    }
}

public enum SyncError: Error, LocalizedError {
    case pathNotConfigured(String)
    case fileNotFound(String)
    case ftpConnectionFailed(String)
    case fileOperationFailed(String)
    case invalidSaveFile(String)
    case unsupportedSystem(String)
    
    public var errorDescription: String? {
        switch self {
        case .pathNotConfigured(let path):
            return "Path not configured: \(path)"
        case .fileNotFound(let filename):
            return "File not found: \(filename)"
        case .ftpConnectionFailed(let host):
            return "FTP connection failed to \(host)"
        case .fileOperationFailed(let operation):
            return "File operation failed: \(operation)"
        case .invalidSaveFile(let reason):
            return "Invalid save file: \(reason)"
        case .unsupportedSystem(let system):
            return "Unsupported system: \(system)"
        }
    }
}

// Constants
public struct Constants {
    static let desmumeFooterSize = 122  // bytes for DS files only
    static let defaultFTPPort = 21
    
    // UserDefaults keys
    static let selectedSystemKey = "selectedSystem"
    static let dsGameNameKey = "dsGameName"
    static let gbaGameNameKey = "gbaGameName"
    static let gbcGameNameKey = "gbcGameName"
    static let openEmuDSPathKey = "openEmuDSPath"
    static let openEmuGBAPathKey = "openEmuGBAPath"
    static let openEmuGBCPathKey = "openEmuGBCPath"
    static let cloudDSPathKey = "cloudDSPath"
    static let cloudGBAPathKey = "cloudGBAPath"
    static let cloudGBCPathKey = "cloudGBCPath"
    static let ftpHostKey = "ftpHost"
    static let ftpPortKey = "ftpPort"
    static let ftpUsernameKey = "ftpUsername"
    static let ftpPasswordKey = "ftpPassword"
}