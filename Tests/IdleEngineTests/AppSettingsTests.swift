import XCTest
@testable import IdleEngine

final class AppSettingsTests: XCTestCase {
    func testRoundTripsThroughPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdleIsleSettingsTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("settings.json")
        let persistence = SettingsPersistence(fileURL: fileURL)

        var settings = AppSettings()
        settings.soundEnabled = false
        settings.screensaverSoundEnabled = true

        try persistence.save(settings)

        let loaded = try XCTUnwrap(persistence.load())
        XCTAssertEqual(loaded, settings)
    }

    func testMissingFieldsFallBackToSensibleDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdleIsleSettingsTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("settings.json")
        let persistence = SettingsPersistence(fileURL: fileURL)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: fileURL)

        let loaded = try XCTUnwrap(persistence.load())
        XCTAssertTrue(loaded.soundEnabled)
        XCTAssertFalse(loaded.screensaverSoundEnabled)
    }

    func testMissingFileReturnsNil() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdleIsleSettingsTests-\(UUID().uuidString)", isDirectory: true)
        let persistence = SettingsPersistence(
            fileURL: directory.appendingPathComponent("settings.json")
        )

        XCTAssertNil(persistence.load())
    }
}
