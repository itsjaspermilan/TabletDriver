import XCTest
@testable import TabletDriverKit

final class DecoMini7V2ProfileTests: XCTestCase {
    let profile = DecoMini7V2Profile()

    func testParsesPositionPressureTiltAndButtons() {
        // status byte: bit1 (pen button 0) + bit3 (eraser) set = 0x0A
        // x=1000 (0x03E8 LE), y=2000 (0x07D0 LE), pressure=8000 (0x1F40 LE)
        // tiltX=-10 (0xF6), tiltY=20 (0x14), no overflow (bytes 10/11 = 0)
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
        // x = 0x1_0000 (65536) needs the overflow bit at byte[10] since it
        // doesn't fit in the 16-bit low word alone.
        var report: [UInt8] = Array(repeating: 0, count: 12)
        report[1] = 0x00
        report[10] = 0x01 // xHigh
        let pen = profile.parsePenReport(report)

        XCTAssertEqual(pen?.x ?? -1, 65536 / profile.maxX, accuracy: 0.000001)
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
        report[1] = 0x10 // bit4 set -> aux report
        report[2] = 0b0000_0101 // buttons 0 and 2 pressed

        XCTAssertTrue(profile.isAuxReport(report))

        let aux = profile.parseAuxReport(report)
        XCTAssertEqual(aux.buttons.count, profile.auxButtonCount)
        XCTAssertEqual(aux.buttons, [true, false, true, false, false, false, false, false])
    }

    func testAuxReportShorterThanExpectedReturnsAllFalse() {
        let aux = profile.parseAuxReport([0x00, 0x10])
        XCTAssertEqual(aux.buttons, Array(repeating: false, count: profile.auxButtonCount))
    }

    func testWakeReportBytesMatchDecodedOTDConfig() {
        // From `Deco mini7 V2.json`'s base64 OutputInitReport "ArAE".
        XCTAssertEqual(profile.outputInitReport, [0x02, 0xB0, 0x04])
    }
}
