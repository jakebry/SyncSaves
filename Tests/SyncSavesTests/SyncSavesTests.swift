import XCTest
@testable import SyncSavesCore

final class SyncSavesTests: XCTestCase {
    func testGameSystemProperties() {
        XCTAssertEqual(GameSystem.ds.fileExtension, "dsv")
        XCTAssertEqual(GameSystem.gba.fileExtension, "sav")
        XCTAssertEqual(GameSystem.gbc.fileExtension, "sav")
        
        XCTAssertEqual(GameSystem.ds.openEmuExtension, "dsv")
        XCTAssertEqual(GameSystem.gba.openEmuExtension, "sav")
        XCTAssertEqual(GameSystem.gbc.openEmuExtension, "sav")
        
        XCTAssertEqual(GameSystem.ds.cloudExtension, "sav")
        XCTAssertEqual(GameSystem.gba.cloudExtension, "sav")
        XCTAssertEqual(GameSystem.gbc.cloudExtension, "sav")
        
        XCTAssertTrue(GameSystem.ds.requiresFooterStripping)
        XCTAssertFalse(GameSystem.gba.requiresFooterStripping)
        XCTAssertFalse(GameSystem.gbc.requiresFooterStripping)
        
        XCTAssertEqual(GameSystem.ds.footerSize, 122)
        XCTAssertEqual(GameSystem.gba.footerSize, 0)
        XCTAssertEqual(GameSystem.gbc.footerSize, 0)
    }
    
    func testSettingsManagerDefaults() {
        let settings = SettingsManager()
        
        XCTAssertEqual(settings.selectedSystem, .ds)
        XCTAssertEqual(settings.dsGameName, "ds_game")
        XCTAssertEqual(settings.gbaGameName, "gba_game")
        XCTAssertEqual(settings.gbcGameName, "gbc_game")
        XCTAssertEqual(settings.ftpPort, 21)
    }
    
    func testSettingsManagerComputedProperties() {
        let settings = SettingsManager()
        
        // Test current properties based on selected system
        settings.selectedSystem = .ds
        XCTAssertEqual(settings.currentGameName, "ds_game")
        
        settings.selectedSystem = .gba
        XCTAssertEqual(settings.currentGameName, "gba_game")
        
        settings.selectedSystem = .gbc
        XCTAssertEqual(settings.currentGameName, "gbc_game")
    }
    
    func testConfiguredSystems() {
        let settings = SettingsManager()
        
        // Initially no systems configured
        XCTAssertTrue(settings.configuredSystems.isEmpty)
        
        // Configure DS
        settings.openEmuDSPath = "/path/to/ds"
        settings.cloudDSPath = "/cloud/ds"
        XCTAssertEqual(settings.configuredSystems, [.ds])
        
        // Configure GBA
        settings.openEmuGBAPath = "/path/to/gba"
        settings.cloudGBAPath = "/cloud/gba"
        XCTAssertEqual(settings.configuredSystems, [.ds, .gba])
        
        // Configure GBC
        settings.openEmuGBCPath = "/path/to/gbc"
        settings.cloudGBCPath = "/cloud/gbc"
        XCTAssertEqual(settings.configuredSystems, [.ds, .gba, .gbc])
    }
}