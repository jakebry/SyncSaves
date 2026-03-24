import Foundation

/// Represents a mapping between OpenEmu file names and Cloud/3DS file names
public struct GameMapping: Identifiable, Codable, Equatable {
    public let id: UUID
    public let openEmuFileName: String
    public let cloudFileName: String
    public let createdAt: Date
    
    public init(id: UUID = UUID(), openEmuFileName: String, cloudFileName: String, createdAt: Date = Date()) {
        self.id = id
        self.openEmuFileName = openEmuFileName
        self.cloudFileName = cloudFileName
        self.createdAt = createdAt
    }
    
    /// Creates a mapping by extracting the base name from file paths
    public static func create(fromOpenEmuPath openEmuPath: String, toCloudPath cloudPath: String) -> GameMapping? {
        let openEmuFileName = (openEmuPath as NSString).lastPathComponent
        let cloudFileName = (cloudPath as NSString).lastPathComponent
        
        guard !openEmuFileName.isEmpty, !cloudFileName.isEmpty else {
            return nil
        }
        
        return GameMapping(
            openEmuFileName: openEmuFileName,
            cloudFileName: cloudFileName
        )
    }
}

/// Manages game mappings using UserDefaults
public class GameMappingManager: ObservableObject {
    @Published public private(set) var mappings: [GameMapping] = []
    
    private let userDefaultsKey = "gameMappings"
    
    public init() {
        loadMappings()
    }
    
    /// Load mappings from UserDefaults
    private func loadMappings() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            mappings = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            mappings = try decoder.decode([GameMapping].self, from: data)
        } catch {
            print("Failed to load game mappings: \(error)")
            mappings = []
        }
    }
    
    /// Save mappings to UserDefaults
    private func saveMappings() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(mappings)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save game mappings: \(error)")
        }
    }
    
    /// Add a new mapping
    public func addMapping(_ mapping: GameMapping) {
        // Remove any existing mapping with the same OpenEmu file name
        mappings.removeAll { $0.openEmuFileName == mapping.openEmuFileName }
        mappings.append(mapping)
        mappings.sort { $0.createdAt > $1.createdAt } // Most recent first
        saveMappings()
    }
    
    /// Remove a mapping by ID
public func removeMapping(withId id: UUID) {
        mappings.removeAll { $0.id == id }
        saveMappings()
    }
    
    /// Remove a mapping by OpenEmu file name
public func removeMapping(forOpenEmuFileName fileName: String) {
        mappings.removeAll { $0.openEmuFileName == fileName }
        saveMappings()
    }
    
    /// Find a mapping by OpenEmu file name
public func mapping(forOpenEmuFileName fileName: String) -> GameMapping? {
        mappings.first { $0.openEmuFileName == fileName }
    }
    
    /// Find a mapping by Cloud file name
public func mapping(forCloudFileName fileName: String) -> GameMapping? {
        mappings.first { $0.cloudFileName == fileName }
    }
    
    /// Translate a file name from one location to another
public func translateFileName(_ fileName: String, from source: FileLocation, to target: FileLocation) -> String {
        switch (source, target) {
        case (.openEmu, .cloud):
            if let mapping = mapping(forOpenEmuFileName: fileName) {
                return mapping.cloudFileName
            }
        case (.cloud, .openEmu):
            if let mapping = mapping(forCloudFileName: fileName) {
                return mapping.openEmuFileName
            }
        default:
            break
        }
        
        // No mapping found, return original name
        return fileName
    }
    
    /// Get all mappings for a specific game system
public func mappings(for system: GameSystem) -> [GameMapping] {
        mappings.filter { mapping in
            mapping.openEmuFileName.hasSuffix(".\(system.fileExtension)") ||
            mapping.cloudFileName.hasSuffix(".\(system.fileExtension)")
        }
    }
    
    /// Clear all mappings
public func clearAll() {
        mappings = []
        saveMappings()
    }
}

/// Represents file locations for translation
public enum FileLocation {
    case openEmu
    case cloud
    case threeDS
}

extension FileLocation {
    var displayName: String {
        switch self {
        case .openEmu: return "OpenEmu"
        case .cloud: return "Cloud"
        case .threeDS: return "3DS"
        }
    }
}