import CoreGraphics

/// Port of OpenTabletDriver's `MacOSAbsolutePointer` + `MacOSVirtualMouse`
/// pattern: move the system cursor absolutely and emulate a mouse click
/// once pen pressure crosses a threshold. Matches OTD's own macOS
/// behavior (no real tablet-pointer/proximity events) rather than
/// inventing an unproven approach for v1.
///
/// Real per-app graduated pressure (e.g. brush size in Affinity) was
/// investigated and found to require macOS's HID digitizer pipeline via a
/// virtual HID device, which needs the restricted
/// `com.apple.developer.hid.virtual.device` entitlement -- confirmed
/// blocked with both the classic IOKit API and CoreHID's modern
/// equivalent. Click-threshold emulation is the practical ceiling without
/// that entitlement, matching OpenTabletDriver's own macOS backend.
public final class CursorPoster {
    /// 0...1, normalized against the connected tablet's own maximum
    /// pressure (see `PenReport.pressure`).
    public var clickThreshold: Double

    private var isDown = false

    public init(clickThreshold: Double = 0.025) {
        self.clickThreshold = clickThreshold
    }

    public func post(pen: PenReport, at point: CGPoint) {
        let shouldBeDown = pen.pressure > clickThreshold
        let button: CGMouseButton = pen.eraser ? .right : .left

        if shouldBeDown != isDown {
            isDown = shouldBeDown
            let type: CGEventType = shouldBeDown
                ? (pen.eraser ? .rightMouseDown : .leftMouseDown)
                : (pen.eraser ? .rightMouseUp : .leftMouseUp)
            postEvent(type: type, at: point, button: button)
        } else {
            let type: CGEventType = isDown
                ? (pen.eraser ? .rightMouseDragged : .leftMouseDragged)
                : .mouseMoved
            postEvent(type: type, at: point, button: button)
        }
    }

    public func reset() {
        isDown = false
    }

    private func postEvent(type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}
