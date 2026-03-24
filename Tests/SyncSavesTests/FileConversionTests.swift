import XCTest
@testable import SyncSavesCore

final class FileConversionTests: XCTestCase {
    
    // Test fixture paths
    private var testFixturesURL: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }
    
    private var testSAVURL: URL {
        testFixturesURL.appendingPathComponent("test_sav.sav")
    }
    
    private var testDSVURL: URL {
        testFixturesURL.appendingPathComponent("test_dsv.dsv")
    }
    
    private var testFooterURL: URL {
        testFixturesURL.appendingPathComponent("footer.bin")
    }
    
    override func setUp() {
        super.setUp()
        // Create test fixtures directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: testFixturesURL.path) {
            try? fileManager.createDirectory(at: testFixturesURL, withIntermediateDirectories: true)
        }
    }
    
    func testDSVToSAVConversion() throws {
        // Skip if test files don't exist
        guard FileManager.default.fileExists(atPath: testDSVURL.path) else {
            throw XCTSkip("Test fixture not available: \(testDSVURL.lastPathComponent)")
        }
        
        // Read the .dsv file
        let dsvData = try Data(contentsOf: testDSVURL)
        
        // Verify the file size (524,288 + 122 = 524,410 bytes)
        XCTAssertEqual(dsvData.count, 524410, "DSV file should be 524,410 bytes (524,288 + 122)")
        
        // Strip the last 122 bytes (DeSmuME footer)
        let savData = dsvData.prefix(dsvData.count - Constants.desmumeFooterSize)
        
        // Verify the stripped data size
        XCTAssertEqual(savData.count, 524288, "Stripped SAV data should be 524,288 bytes")
        
        // Compare with original .sav file byte-for-byte
        let expectedSAVData = try Data(contentsOf: testSAVURL)
        XCTAssertEqual(savData, expectedSAVData, "Stripped DSV should match SAV byte-for-byte")
    }
    
    func testSAVToDSVConversion() throws {
        // Skip if test files don't exist
        guard FileManager.default.fileExists(atPath: testSAVURL.path),
              FileManager.default.fileExists(atPath: testDSVURL.path) else {
            throw XCTSkip("Test fixtures not available")
        }
        
        // Read the .sav file
        let savData = try Data(contentsOf: testSAVURL)
        
        // Verify the file size
        XCTAssertEqual(savData.count, 524288, "SAV file should be 524,288 bytes")
        
        // Read the .dsv file to extract its footer
        let dsvData = try Data(contentsOf: testDSVURL)
        
        // Verify the .dsv file size
        XCTAssertEqual(dsvData.count, 524410, "DSV file should be 524,410 bytes")
        
        // Extract the last 122 bytes as footer
        let footer = dsvData.suffix(Constants.desmumeFooterSize)
        
        // Verify footer size
        XCTAssertEqual(footer.count, Constants.desmumeFooterSize, "Footer should be 122 bytes")
        
        // Reconstruct .dsv by appending footer to .sav
        let reconstructedDSVData = savData + footer
        
        // Verify reconstructed file matches original .dsv
        XCTAssertEqual(reconstructedDSVData, dsvData, "Reconstructed DSV should match original DSV byte-for-byte")
    }
    
    func testFileConversionEdgeCases() {
        // Test with empty data
        let emptyData = Data()
        XCTAssertEqual(emptyData.count, 0)
        
        // Test with data smaller than footer
        let smallData = Data([0x01, 0x02, 0x03])
        XCTAssertLessThan(smallData.count, Constants.desmumeFooterSize)
        
        // Test footer extraction with exact footer size
        let exactFooterSizeData = Data(count: Constants.desmumeFooterSize)
        let extractedFooter = exactFooterSizeData.suffix(Constants.desmumeFooterSize)
        XCTAssertEqual(extractedFooter.count, Constants.desmumeFooterSize)
    }
    
    func testGameMappingModel() {
        // Test GameMapping struct
        let mapping = GameMapping(
            id: UUID(),
            openEmuFileName: "Pokemon - White Version (USA, Europe) (NDSi Enhanced).dsv",
            cloudFileName: "Pokemon White.sav",
            createdAt: Date()
        )
        
        XCTAssertEqual(mapping.openEmuFileName, "Pokemon - White Version (USA, Europe) (NDSi Enhanced).dsv")
        XCTAssertEqual(mapping.cloudFileName, "Pokemon White.sav")
        XCTAssertNotNil(mapping.id)
        XCTAssertNotNil(mapping.createdAt)
    }
    
    func testFileNameTranslation() {
        let mappingManager = GameMappingManager()
        
        // Test translation from OpenEmu to Cloud
        let openEmuName = "Pokemon - White Version (USA, Europe) (NDSi Enhanced).dsv"
        let expectedCloudName = "Pokemon White.sav"
        
        // Add a mapping
        let mapping = GameMapping(
            openEmuFileName: openEmuName,
            cloudFileName: expectedCloudName
        )
        mappingManager.addMapping(mapping)
        
        // Test translation
        let translatedName = mappingManager.translateFileName(openEmuName, from: .openEmu, to: .cloud)
        XCTAssertEqual(translatedName, expectedCloudName)
        
        // Test reverse translation
        let reverseTranslatedName = mappingManager.translateFileName(expectedCloudName, from: .cloud, to: .openEmu)
        XCTAssertEqual(reverseTranslatedName, openEmuName)
        
        // Test translation with no mapping
        let unknownName = "Unknown Game.dsv"
        let untranslatedName = mappingManager.translateFileName(unknownName, from: .openEmu, to: .cloud)
        XCTAssertEqual(untranslatedName, unknownName)
    }
}