import Foundation

/// Describes one supported tablet model: how to recognize it over USB HID,
/// how to wake it up, and how to parse its raw input reports into the
/// driver's generic `PenReport`/`AuxReport` types.
///
/// To add support for a new tablet, implement this protocol (see
/// `DecoMini7V2Profile` for a worked example) and add an instance to
/// `TabletProfileRegistry.all`. See CONTRIBUTING.md for the full walkthrough
/// of finding these values for a new device.
public protocol TabletProfile {
    /// Human-readable name shown in the UI and logs.
    var name: String { get }

    /// USB vendor ID, e.g. 0x28BD for XP-Pen. Find via `ioreg -p IOUSB` or
    /// System Information > USB while the tablet is plugged in.
    var vendorID: Int { get }
    /// USB product ID for this specific model.
    var productID: Int { get }

    /// Byte length of the tablet's input (pen/aux) HID reports.
    var inputReportLength: Int { get }
    /// Byte length of the tablet's output reports (used for `outputInitReport`).
    var outputReportLength: Int { get }
    /// A "wake up" output report some tablets need before they start
    /// streaming real input reports. Empty if not needed.
    var outputInitReport: [UInt8] { get }

    /// Native maximum X/Y coordinates the tablet reports, used only to
    /// normalize `PenReport.x`/`.y` to 0...1 -- the rest of the driver never
    /// sees these raw values.
    var maxX: Double { get }
    var maxY: Double { get }
    /// Native maximum pressure value, used to normalize `PenReport.pressure`.
    var maxPressure: UInt16 { get }

    /// Number of express keys this tablet has (0 if none).
    var auxButtonCount: Int { get }
    /// Number of physical side buttons on the pen itself.
    var penButtonCount: Int { get }

    /// True if `report` should be ignored (e.g. pen lifted out of range).
    func isOutOfRange(_ report: [UInt8]) -> Bool
    /// True if `report` is an express-key/dial report rather than a pen report.
    func isAuxReport(_ report: [UInt8]) -> Bool
    /// Parses a pen-position report. Returns nil if `report` is malformed.
    func parsePenReport(_ report: [UInt8]) -> PenReport?
    /// Parses an express-key/dial report.
    func parseAuxReport(_ report: [UInt8]) -> AuxReport
}
