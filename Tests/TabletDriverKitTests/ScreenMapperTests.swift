import XCTest
@testable import TabletDriverKit

final class ScreenMapperTests: XCTestCase {
    func testMapsCornersAndCenter() {
        let rect = CGRect(x: 100, y: 200, width: 1000, height: 500)

        XCTAssertEqual(ScreenMapper.map(x: 0, y: 0, into: rect), CGPoint(x: 100, y: 200))
        XCTAssertEqual(ScreenMapper.map(x: 1, y: 1, into: rect), CGPoint(x: 1100, y: 700))
        XCTAssertEqual(ScreenMapper.map(x: 0.5, y: 0.5, into: rect), CGPoint(x: 600, y: 450))
    }

    func testClampsOutOfRangeInputCoordinates() {
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 500)

        XCTAssertEqual(ScreenMapper.map(x: -0.5, y: -1, into: rect), CGPoint(x: 0, y: 0))
        XCTAssertEqual(ScreenMapper.map(x: 1.5, y: 2, into: rect), CGPoint(x: 1000, y: 500))
    }

    func testTargetDefaultsToMainDisplayAndIsSettable() {
        let mapper = ScreenMapper(target: .activeWindow)
        XCTAssertEqual(mapper.target, .activeWindow)

        mapper.target = .display(CGMainDisplayID())
        XCTAssertEqual(mapper.target, .display(CGMainDisplayID()))
    }
}
