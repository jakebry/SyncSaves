import Foundation

/// Scans directories for save files and provides fuzzy matching
public class FileScanner: ObservableObject {
    
    public init() {}
    
    /// Scans a directory for save files of a specific system
    /// - Parameters:
    ///   - directoryPath: Path to scan
    ///   - system: Game system to filter by
    ///   - location: File location (OpenEmu or Cloud) to determine which extension to use
    /// - Returns: Array of save file names found
    public func scanDirectory(_ directoryPath: String, for system: GameSystem, location: FileLocation = .openEmu) -> [String] {
        guard !directoryPath.isEmpty else {
            print("Warning: Cannot scan empty directory path for \(system.displayName)")
            return []
        }
        
        let expandedPath = (directoryPath as NSString).expandingTildeInPath
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)
            let extensionToUse = location == .openEmu ? system.openEmuExtension : system.cloudExtension
            
            let saveFiles = contents.filter { fileName in
                // For OpenEmu location, only include files with the correct extension
                if location == .openEmu {
                    return fileName.lowercased().hasSuffix(".\(extensionToUse)")
                }
                
                // For Cloud location, include:
                // 1. Files with the correct extension (e.g., .sav)
                // 2. Delta Emulator hash-based files: GameSave-[HASH]-gameSave (no extension)
                let hasCorrectExtension = fileName.lowercased().hasSuffix(".\(extensionToUse)")
                let isDeltaHashFile = fileName.hasPrefix("GameSave-") && fileName.hasSuffix("-gameSave")
                
                return hasCorrectExtension || isDeltaHashFile
            }
            
            print("Info: Found \(saveFiles.count) \(system.displayName) save files in \(expandedPath) (looking for .\(extensionToUse) or Delta hash files)")
            return saveFiles.sorted()
        } catch {
            print("Error: Failed to scan directory \(expandedPath): \(error)")
            return []
        }
    }
    
    /// Scans all configured directories for save files
    /// - Parameter settings: Settings manager with configured paths
    /// - Returns: Dictionary mapping system to arrays of save files found in OpenEmu and Cloud directories
    public func scanAllDirectories(using settings: SettingsManager) -> [GameSystem: (openEmuFiles: [String], cloudFiles: [String])] {
        var results: [GameSystem: (openEmuFiles: [String], cloudFiles: [String])] = [:]
        
        for system in GameSystem.allCases {
            let openEmuPath = settings.openEmuPath(for: system)
            let cloudPath = settings.cloudPath(for: system)
            
            let openEmuFiles = scanDirectory(openEmuPath, for: system, location: .openEmu)
            let cloudFiles = scanDirectory(cloudPath, for: system, location: .cloud)
            
            if !openEmuFiles.isEmpty || !cloudFiles.isEmpty {
                results[system] = (openEmuFiles, cloudFiles)
            }
        }
        
        return results
    }
    
    /// Performs fuzzy matching between two file names
    /// - Parameters:
    ///   - fileName1: First file name
    ///   - fileName2: Second file name
    /// - Returns: Similarity score between 0.0 and 1.0
    public func fuzzyMatch(_ fileName1: String, _ fileName2: String) -> Double {
        let name1 = cleanFileName(fileName1)
        let name2 = cleanFileName(fileName2)
        
        // Exact match after cleaning
        if name1 == name2 {
            return 1.0
        }
        
        // Check for common game name patterns
        let commonWords = ["pokemon", "zelda", "mario", "kirby", "metroid", "fire", "emblem", "dragon", "quest", "final", "fantasy", "white", "black", "red", "blue", "gold", "silver", "crystal", "ruby", "sapphire", "emerald", "diamond", "pearl", "platinum", "heart", "soul"]
        
        var score = 0.0
        let maxScorePerWord = 1.0 / Double(commonWords.count)
        
        for word in commonWords {
            if name1.contains(word) && name2.contains(word) {
                score += maxScorePerWord
            }
        }
        
        // Check for version numbers
        let versionPatterns = ["\\d+", "i+", "v+", "\\s+\\d+", "\\s+i+", "\\s+v+"]
        for pattern in versionPatterns {
            if name1.range(of: pattern, options: .regularExpression) != nil &&
               name2.range(of: pattern, options: .regularExpression) != nil {
                score += 0.1
            }
        }
        
        // Check for similar length (within 20%)
        let length1 = Double(name1.count)
        let length2 = Double(name2.count)
        let lengthRatio = min(length1, length2) / max(length1, length2)
        if lengthRatio > 0.8 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    /// Finds the best matching pairs between OpenEmu and Cloud files
    /// - Parameters:
    ///   - openEmuFiles: Array of OpenEmu file names
    ///   - cloudFiles: Array of Cloud file names
    ///   - system: Game system
    /// - Returns: Array of suggested mappings with similarity scores
    public func findSuggestedMappings(openEmuFiles: [String], cloudFiles: [String], for system: GameSystem) -> [(openEmuFile: String, cloudFile: String, score: Double)] {
        var suggestions: [(openEmuFile: String, cloudFile: String, score: Double)] = []
        
        for openEmuFile in openEmuFiles {
            var bestMatch: (cloudFile: String, score: Double)? = nil
            
            for cloudFile in cloudFiles {
                let score = fuzzyMatch(openEmuFile, cloudFile)
                
                if let currentBest = bestMatch {
                    if score > currentBest.score {
                        bestMatch = (cloudFile, score)
                    }
                } else if score > 0.3 { // Minimum threshold
                    bestMatch = (cloudFile, score)
                }
            }
            
            if let bestMatch = bestMatch {
                suggestions.append((openEmuFile, bestMatch.cloudFile, bestMatch.score))
            }
        }
        
        // Sort by similarity score (highest first)
        return suggestions.sorted { $0.score > $1.score }
    }
    
    /// Cleans a file name by removing common prefixes/suffixes and extensions
    private func cleanFileName(_ fileName: String) -> String {
        var cleaned = fileName.lowercased()
        
        // Remove file extension
        if let dotIndex = cleaned.lastIndex(of: ".") {
            cleaned = String(cleaned[..<dotIndex])
        }
        
        // Remove common prefixes/suffixes
        let removals = [
            "pokemon - ", "pokemon ", "the legend of zelda - ", "zelda - ",
            "super mario ", "mario ", "new super mario bros ", "new super mario bros. ",
            "version", "ver.", "ver", "v.", "v", "usa", "eur", "jpn", "rev",
            "(", ")", "[", "]", "{", "}", ".", ",", "-", "_", "  "
        ]
        
        for removal in removals {
            cleaned = cleaned.replacingOccurrences(of: removal, with: " ")
        }
        
        // Remove extra spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - SettingsManager Extensions
extension SettingsManager {
    /// Gets the OpenEmu path for a specific system
    public func openEmuPath(for system: GameSystem) -> String {
        switch system {
        case .ds: return openEmuDSPath
        case .gba: return openEmuGBAPath
        case .gbc: return openEmuGBCPath
        }
    }
    
    /// Gets the Cloud path for a specific system
    public func cloudPath(for system: GameSystem) -> String {
        switch system {
        case .ds: return cloudDSPath
        case .gba: return cloudGBAPath
        case .gbc: return cloudGBCPath
        }
    }
    
    /// Detects the game system from a file name based on extension
    func detectSystem(from fileName: String, location: FileLocation = .openEmu) -> GameSystem? {
        if fileName.lowercased().hasSuffix(".dsv") {
            return .ds
        } else if fileName.lowercased().hasSuffix(".sav") {
            // For .sav files, we need to check the directory to determine if it's GBA or GBC
            // This will be handled by the caller based on which directory the file was found in
            // However, if we're in the cloud location, .sav could be DS, GBA, or GBC
            // The caller should know which system they're scanning for
            return nil // Let caller determine based on context
        }
        return nil
    }
}