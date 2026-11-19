import Foundation

/// XP-Pen Deco 640 (IT640), ported from OpenTabletDriver's `Deco 640 (IT640).json`
/// config (0.6.x branch) and its `XP_PenReportParser`/`XP_PenTabletOverflowReport`/
/// `XP_PenAuxReport` classes. Wire format is identical to `DecoMini7V2Profile`;
/// only the IDs and digitizer ranges differ.
public struct Deco640Profile: TabletProfile {
    public let name = "XP-Pen Deco 640"
    public let vendorID = 0x28BD   // 10429
    public let productID = 0x2904  // 10500

    public let inputReportLength = 12
    public let outputReportLength = 20
    public let outputInitReport: [UInt8] = [0x02, 0xB0, 0x04]

    public let maxX: Double = 31998
    public let maxY: Double = 17998
    public let maxPressure: UInt16 = 16383

    public let auxButtonCount = 8
    public let penButtonCount = 2

    public init() {}

    public func isOutOfRange(_ report: [UInt8]) -> Bool {
        report.count > 1 && report[1] == 0xC0
    }

    public func isAuxReport(_ report: [UInt8]) -> Bool {
        report.count > 1 && report[1].isBitSet(4)
    }

    public func parsePenReport(_ report: [UInt8]) -> PenReport? {
        guard report.count >= inputReportLength else { return nil }

        let xLow = UInt32(report[2]) | (UInt32(report[3]) << 8)
        let yLow = UInt32(report[4]) | (UInt32(report[5]) << 8)
        let xHigh = UInt32(report[10])
        let yHigh = UInt32(report[11])

        let x = Double(xLow | (xHigh << 16))
        let y = Double(yLow | (yHigh << 16))
        let pressure = UInt16(report[6]) | (UInt16(report[7]) << 8)

        let status = report[1]
        return PenReport(
            x: x / maxX,
            y: y / maxY,
            pressure: min(1, Double(pressure) / Double(maxPressure)),
            tiltX: Int8(bitPattern: report[8]),
            tiltY: Int8(bitPattern: report[9]),
            penButtons: [status.isBitSet(1), status.isBitSet(2)],
            eraser: status.isBitSet(3)
        )
    }

    public func parseAuxReport(_ report: [UInt8]) -> AuxReport {
        let byteIndex = 2
        guard report.count > byteIndex else {
            return AuxReport(buttons: Array(repeating: false, count: auxButtonCount))
        }
        let byte = report[byteIndex]
        return AuxReport(buttons: (0..<auxButtonCount).map { byte.isBitSet($0) })
    }
}
