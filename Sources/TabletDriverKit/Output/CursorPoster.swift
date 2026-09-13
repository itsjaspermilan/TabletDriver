import CoreGraphics

/// Moves the system cursor and emulates clicks from a pressure threshold,
/// while embedding real tablet pressure/tilt data on the *same* mouse-type
/// `CGEvent` -- ported from OpenTabletDriver's `0.6.x` branch fix for
/// pressure sensitivity in Adobe/Affinity-class software on macOS
/// (`MacOSVirtualMouse.cs`, PR #3761 "Fix support for pressure sensitivity
/// in Adobe software on macOS").
///
/// Two earlier attempts in this project failed because they used the wrong
/// mechanism: setting tablet fields with no subtype marker (apps didn't
/// recognize the event as tablet data at all), and posting a genuinely
/// separate `.tabletPointer`-typed `CGEvent` (which is not what triggers
/// `NSEvent.subtype == .tabletPoint` dispatch either). The actual
/// mechanism, confirmed against OTD's merged fix: keep the event as an
/// ordinary mouse-type `CGEvent`, but set `CGEventField.mouseEventSubtype`
/// to mark it as a tablet point/proximity event *before* setting any other
/// tablet field (order matters), and set a Wacom-specific capability mask
/// on the proximity event -- Adobe-class apps (including Affinity)
/// apparently gate real pressure support on recognizing that mask, per
/// OTD's own comment: "Adobe officially supports only Wacom tablets... the
/// capabilityMask is essential for Adobe software to recognize tablet
/// pressure sensitivity."
public final class CursorPoster {
    /// 0...1, normalized against the connected tablet's own maximum
    /// pressure (see `PenReport.pressure`).
    public var clickThreshold: Double

    private var isDown = false
    private var hasSentProximity = false

    // Wacom's own capability mask bits (see
    // https://github.com/Wacom-Developer/wacom-device-kit-macos-scribble-demo,
    // Wacom.h) -- deviceId | absX | absY | buttons | tiltX | tiltY | pressure.
    private static let capabilityMask: Int64 = 0x001 | 0x002 | 0x004 | 0x040 | 0x080 | 0x100 | 0x400
    // Arbitrary fixed nonzero ID; a zero/trivial deviceId is not enough for
    // Adobe-class apps to map tablet events to the capabilities above.
    private static let deviceID: Int64 = 5303613955435230461

    private static let tabletPointSubtype: Int64 = 1
    private static let tabletProximitySubtype: Int64 = 2

    public init(clickThreshold: Double = 0.025) {
        self.clickThreshold = clickThreshold
    }

    public func post(pen: PenReport, at point: CGPoint) {
        if !hasSentProximity {
            postProximity(eraser: pen.eraser)
            hasSentProximity = true
        }

        let type = nextEventType(for: pen)
        postEvent(type: type, at: point, pen: pen)
    }

    public func reset() {
        isDown = false
        hasSentProximity = false
    }

    /// The pure click/drag/move state-machine decision, separated from the
    /// actual `CGEvent` side effect so it can be unit tested without
    /// posting real system-wide events.
    func nextEventType(for pen: PenReport) -> CGEventType {
        let shouldBeDown = pen.pressure > clickThreshold

        if shouldBeDown != isDown {
            isDown = shouldBeDown
            return shouldBeDown
                ? (pen.eraser ? .rightMouseDown : .leftMouseDown)
                : (pen.eraser ? .rightMouseUp : .leftMouseUp)
        }
        return isDown
            ? (pen.eraser ? .rightMouseDragged : .leftMouseDragged)
            : .mouseMoved
    }

    private func postEvent(type: CGEventType, at point: CGPoint, pen: PenReport) {
        let button: CGMouseButton = pen.eraser ? .right : .left
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return }

        // Subtype must be set before the tablet-specific fields below --
        // CGEvent fields are stored in a type/subtype-determined union, so
        // setting them in the wrong order silently drops the values.
        event.setIntegerValueField(.mouseEventSubtype, value: Self.tabletPointSubtype)
        event.setIntegerValueField(.tabletEventPointButtons, value: pen.penButtons.contains(true) ? 1 : 0)
        event.setIntegerValueField(.tabletEventDeviceID, value: Self.deviceID)
        event.setDoubleValueField(.mouseEventPressure, value: pen.pressure)
        event.setDoubleValueField(.tabletEventPointPressure, value: pen.pressure)
        event.setDoubleValueField(.tabletEventTiltX, value: Double(pen.tiltX) / 90.0)
        event.setDoubleValueField(.tabletEventTiltY, value: Double(pen.tiltY) / 90.0)

        event.post(tap: .cghidEventTap)
    }

    private func postProximity(eraser: Bool) {
        guard let event = CGEvent(source: nil) else { return }
        event.setIntegerValueField(.mouseEventSubtype, value: Self.tabletProximitySubtype)
        event.setIntegerValueField(.tabletProximityEventEnterProximity, value: 1)
        event.setIntegerValueField(.tabletProximityEventPointerType, value: eraser ? 3 : 1) // NSPointingDeviceType: pen=1, eraser=3
        event.setIntegerValueField(.tabletProximityEventCapabilityMask, value: Self.capabilityMask)
        event.setIntegerValueField(.tabletProximityEventDeviceID, value: Self.deviceID)
        event.post(tap: .cghidEventTap)
    }
}
