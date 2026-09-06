import XCTest
import CoreGraphics
@testable import TabletDriverKit

final class DriverPreferencesTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DriverPreferencesTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testDefaultsWhenNothingPersistedYet() {
        let prefs = DriverPreferences(applicationSupportDirectory: tempDirectory)
        XCTAssertEqual(prefs.clickThreshold, 0.025, accuracy: 0.000001)
    }

    func testPersistsAcrossInstances() {
        do {
            let prefs = DriverPreferences(applicationSupportDirectory: tempDirectory)
            prefs.clickThreshold = 0.5
            prefs.mappingTarget = .activeWindow
        }

        let reloaded = DriverPreferences(applicationSupportDirectory: tempDirectory)
        XCTAssertEqual(reloaded.clickThreshold, 0.5, accuracy: 0.000001)
        XCTAssertEqual(reloaded.mappingTarget, .activeWindow)
    }
}
