import XCTest
@testable import TabletDriverKit

final class Deco640ProfileTests: XCTestCase {
    let profile = Deco640Profile()

    func testIdentifiersMatchOTDConfig() {
        XCTAssertEqual(profile.vendorID, 10429)
        XCTAssertEqual(profile.productID, 10500)
    }

    func testParsesPositionPressureTiltAndButtons() {
        let report: [UInt8] = [0x00, 0x0A, 0xE8, 0x03, 0xD0, 0x07, 0x40, 0x1F, 0xF6, 0x14, 0x00, 0x00]

        let pen = profile.parsePenReport(report)

        XCTAssertNotNil(pen)
        XCTAssertEqual(pen?.x ?? -1, 1000 / profile.maxX, accuracy: 0.000001)
        XCTAssertEqual(pen?.y ?? -1, 2000 / profile.maxY, accuracy: 0.000001)
        XCTAssertEqual(pen?.pressure ?? -1, 8000 / Double(profile.maxPressure), accuracy: 0.000001)
        XCTAssertEqual(pen?.tiltX, -10)
        XCTAssertEqual(pen?.tiltY, 20)
        XCTAssertEqual(pen?.penButtons, [true, false])
        XCTAssertEqual(pen?.eraser, true)
    }

    func testHighCoordinateOverflowBitsExtendPosition() {
        var report: [UInt8] = Array(repeating: 0, count: 12)
        report[10] = 0x00
        report[2] = 0xFF
        report[3] = 0x7C // 31999 low word, within range
        let pen = profile.parsePenReport(report)
        XCTAssertEqual(pen?.x ?? -1, 31999 / profile.maxX, accuracy: 0.000001)

        report[10] = 0x01
        XCTAssertEqual(profile.parsePenReport(report)?.x ?? -1, Double(0x1_7CFF) / profile.maxX, accuracy: 0.000001)
    }

    func testPressurePastMaximumIsClampedToOne() {
        var report: [UInt8] = Array(repeating: 0, count: 12)
        report[6] = 0xFF
        report[7] = 0xFF
        XCTAssertEqual(profile.parsePenReport(report)?.pressure, 1)
    }

    func testRejectsUndersizedReport() {
        XCTAssertNil(profile.parsePenReport(Array(repeating: 0, count: 5)))
    }

    func testOutOfRangeReport() {
        var report: [UInt8] = Array(repeating: 0, count: 12)
        report[1] = 0xC0
        XCTAssertTrue(profile.isOutOfRange(report))
        report[1] = 0x00
        XCTAssertFalse(profile.isOutOfRange(report))
    }

    func testAuxReportDetectionAndParsing() {
        var report: [UInt8] = Array(repeating: 0, count: 12)
        report[1] = 0x10
        report[2] = 0b0000_0101

        XCTAssertTrue(profile.isAuxReport(report))
        XCTAssertEqual(profile.parseAuxReport(report).buttons,
                       [true, false, true, false, false, false, false, false])
    }

    func testWakeReportBytesMatchDecodedOTDConfig() {
        // From `Deco 640 (IT640).json`'s base64 OutputInitReport "ArAE".
        XCTAssertEqual(profile.outputInitReport, [0x02, 0xB0, 0x04])
    }
}
