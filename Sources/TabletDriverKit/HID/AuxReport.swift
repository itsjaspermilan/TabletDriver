import Foundation

/// Express-key/dial state for one report, sized to whatever the active
/// `TabletProfile` declares (`auxButtonCount`).
public struct AuxReport {
    public let buttons: [Bool]

    public init(buttons: [Bool]) {
        self.buttons = buttons
    }
}
