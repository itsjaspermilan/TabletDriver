import Foundation

/// A single pen sample, in device-agnostic normalized units so the rest of
/// the driver (cursor mapping, click emulation, the test canvas) never
/// needs to know which tablet is actually connected.
public struct PenReport {
    /// 0...1 across the tablet's active area.
    public let x: Double
    /// 0...1 across the tablet's active area.
    public let y: Double
    /// 0...1 of the tablet's maximum pressure.
    public let pressure: Double
    public let tiltX: Int8
    public let tiltY: Int8
    public let penButtons: [Bool]
    public let eraser: Bool

    public init(x: Double, y: Double, pressure: Double, tiltX: Int8, tiltY: Int8, penButtons: [Bool], eraser: Bool) {
        self.x = x
        self.y = y
        self.pressure = pressure
        self.tiltX = tiltX
        self.tiltY = tiltY
        self.penButtons = penButtons
        self.eraser = eraser
    }
}

extension UInt8 {
    public func isBitSet(_ bit: Int) -> Bool {
        (self & (1 << bit)) != 0
    }
}
