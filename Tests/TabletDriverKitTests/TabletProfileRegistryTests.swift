import XCTest
@testable import TabletDriverKit

/// Sanity checks for the registry itself -- these catch a common mistake
/// when adding a new `TabletProfile` (copy-pasting an existing one and
/// forgetting to change the VID/PID), not the profiles' own parsing logic.
final class TabletProfileRegistryTests: XCTestCase {
    func testRegistryIsNotEmpty() {
        XCTAssertFalse(TabletProfileRegistry.all.isEmpty)
    }

    func testNoTwoProfilesShareAVendorProductIDPair() {
        var seen = Set<String>()
        for profile in TabletProfileRegistry.all {
            let key = "\(profile.vendorID):\(profile.productID)"
            XCTAssertFalse(seen.contains(key), "Duplicate VID/PID \(key) used by \(profile.name)")
            seen.insert(key)
        }
    }

    func testEveryProfileHasPlausibleValues() {
        for profile in TabletProfileRegistry.all {
            XCTAssertFalse(profile.name.isEmpty)
            XCTAssertGreaterThan(profile.inputReportLength, 0, "\(profile.name)")
            XCTAssertGreaterThan(profile.maxX, 0, "\(profile.name)")
            XCTAssertGreaterThan(profile.maxY, 0, "\(profile.name)")
            XCTAssertGreaterThan(profile.maxPressure, 0, "\(profile.name)")
            XCTAssertGreaterThanOrEqual(profile.auxButtonCount, 0, "\(profile.name)")
            XCTAssertGreaterThanOrEqual(profile.penButtonCount, 0, "\(profile.name)")
        }
    }
}
