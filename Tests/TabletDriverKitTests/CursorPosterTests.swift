import XCTest
import CoreGraphics
@testable import TabletDriverKit

final class CursorPosterTests: XCTestCase {
    private func pen(pressure: Double, eraser: Bool = false) -> PenReport {
        PenReport(x: 0.5, y: 0.5, pressure: pressure, tiltX: 0, tiltY: 0, penButtons: [false, false], eraser: eraser)
    }

    func testStaysUpBelowThreshold() {
        let poster = CursorPoster(clickThreshold: 0.1)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.05)), .mouseMoved)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.0)), .mouseMoved)
    }

    func testCrossingThresholdFiresDownThenDragged() {
        let poster = CursorPoster(clickThreshold: 0.1)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.05)), .mouseMoved)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.5)), .leftMouseDown)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.6)), .leftMouseDragged)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.05)), .leftMouseUp)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.0)), .mouseMoved)
    }

    func testEraserUsesRightClickInstead() {
        let poster = CursorPoster(clickThreshold: 0.1)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.5, eraser: true)), .rightMouseDown)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.6, eraser: true)), .rightMouseDragged)
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.0, eraser: true)), .rightMouseUp)
    }

    func testResetClearsDownState() {
        let poster = CursorPoster(clickThreshold: 0.1)
        _ = poster.nextEventType(for: pen(pressure: 0.5))
        poster.reset()
        // Immediately after reset, pressure still above threshold should
        // read as a fresh down transition, not a drag.
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.5)), .leftMouseDown)
    }

    func testPressureExactlyAtThresholdDoesNotClick() {
        let poster = CursorPoster(clickThreshold: 0.1)
        // Strictly greater-than semantics: exactly-at-threshold stays up.
        XCTAssertEqual(poster.nextEventType(for: pen(pressure: 0.1)), .mouseMoved)
    }

    func testLeavingRangeWhileDownReleasesTheClick() {
        let poster = CursorPoster(clickThreshold: 0.1)
        _ = poster.nextEventType(for: pen(pressure: 0.5))
        XCTAssertEqual(poster.rangeExitEventType(), .leftMouseUp)
    }

    func testLeavingRangeWithEraserDownReleasesRightClick() {
        let poster = CursorPoster(clickThreshold: 0.1)
        _ = poster.nextEventType(for: pen(pressure: 0.5, eraser: true))
        XCTAssertEqual(poster.rangeExitEventType(), .rightMouseUp)
    }

    func testLeavingRangeWhileUpDoesNothing() {
        let poster = CursorPoster(clickThreshold: 0.1)
        _ = poster.nextEventType(for: pen(pressure: 0.05))
        XCTAssertNil(poster.rangeExitEventType())
    }
}
