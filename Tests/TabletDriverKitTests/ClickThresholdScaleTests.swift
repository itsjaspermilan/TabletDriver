import XCTest
@testable import TabletDriverKit

final class ClickThresholdScaleTests: XCTestCase {
    func testEndpointsAndMidpoint() {
        XCTAssertEqual(ClickThresholdScale.threshold(at: 0), 0.01, accuracy: 0.000001)
        XCTAssertEqual(ClickThresholdScale.threshold(at: 0.5), 0.1, accuracy: 0.000001)
        XCTAssertEqual(ClickThresholdScale.threshold(at: 1), 1, accuracy: 0.000001)
    }

    func testPositionRoundTrips() {
        for threshold in [0.01, 0.025, 0.1, 0.42, 1] {
            let position = ClickThresholdScale.position(for: threshold)
            XCTAssertEqual(ClickThresholdScale.threshold(at: position), threshold, accuracy: 0.000001)
        }
    }

    func testOutOfRangeValuesAreClamped() {
        XCTAssertEqual(ClickThresholdScale.position(for: 0.001), 0)
        XCTAssertEqual(ClickThresholdScale.threshold(at: 2), 1, accuracy: 0.000001)
    }

    func testLabelKeepsADecimalForSmallThresholds() {
        XCTAssertEqual(ClickThresholdScale.label(for: 0.025), "2.5%")
        XCTAssertEqual(ClickThresholdScale.label(for: 0.42), "42%")
    }
}
