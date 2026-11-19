import Foundation

/// Maps a 0...1 slider position onto the click threshold logarithmically
/// (1% at the left, 10% in the middle, 100% at the right) -- comfortable
/// thresholds sit in the 1-10% range, which a linear slider squeezes into
/// its first tenth.
public enum ClickThresholdScale {
    static let minimum = 0.01
    static let maximum = 1.0

    public static func threshold(at position: Double) -> Double {
        let clamped = min(max(position, 0), 1)
        return minimum * pow(maximum / minimum, clamped)
    }

    public static func position(for threshold: Double) -> Double {
        let clamped = min(max(threshold, minimum), maximum)
        return log(clamped / minimum) / log(maximum / minimum)
    }

    /// "2.5%" below 10%, "42%" above, so small thresholds don't all
    /// round to the same integer.
    public static func label(for threshold: Double) -> String {
        let percent = threshold * 100
        return percent < 10 ? String(format: "%.1f%%", percent) : String(format: "%.0f%%", percent)
    }
}
