import ApplicationServices
import AppKit
import CoreGraphics

/// Maps raw tablet coordinates onto either a fixed display or the
/// currently-focused app's frontmost window, in the top-left-origin
/// "global display" coordinate space that `CGEvent` actually uses.
///
/// `NSScreen.frame` is in Cocoa's bottom-left-origin space, which only
/// happens to numerically match `CGDisplayBounds` for the main display --
/// using it directly for `CGEvent` positioning silently breaks on any
/// secondary display. `CGDisplayBounds`/Accessibility window frames are
/// already in the correct space, so this type uses only those.
public final class ScreenMapper {
    public enum Target: Codable, Equatable {
        case display(CGDirectDisplayID)
        case activeWindow
    }

    public var target: Target {
        didSet { cachedDisplayRect = nil }
    }

    // Everything below is only touched on the main thread, which is where
    // HID reports (and so `map`) arrive.
    private var cachedDisplayRect: CGRect?
    private var screenObserver: NSObjectProtocol?

    // Looking up the frontmost window is several synchronous Accessibility
    // round trips into *another* app; doing that inline for every pen
    // report froze the cursor for as long as that app was unresponsive.
    // It's fetched off the main thread instead, at most every
    // `windowRefreshInterval`, and `map` always uses the latest result.
    private var windowFrame: CGRect?
    private var windowFrameFetchedAt: TimeInterval = -.infinity
    private var isFetchingWindowFrame = false
    private static let windowRefreshInterval: TimeInterval = 0.1
    private static let windowQueue = DispatchQueue(label: "com.tabletdriver.window-frame", qos: .userInteractive)

    public init(target: Target) {
        self.target = target
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cachedDisplayRect = nil
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    /// `x`/`y` are already normalized 0...1 (see `PenReport`).
    public func map(x: Double, y: Double) -> CGPoint {
        Self.map(x: x, y: y, into: currentRect())
    }

    /// The pure coordinate math, separated from `currentRect()`'s system
    /// calls so it can be unit tested without depending on real display
    /// state (which a headless CI runner may not have).
    static func map(x: Double, y: Double, into rect: CGRect) -> CGPoint {
        let nx = x.clamped(to: 0...1)
        let ny = y.clamped(to: 0...1)
        return CGPoint(
            x: rect.origin.x + nx * rect.width,
            y: rect.origin.y + ny * rect.height
        )
    }

    public func currentRect() -> CGRect {
        switch target {
        case .display(let id):
            if let cachedDisplayRect { return cachedDisplayRect }
            let bounds = CGDisplayBounds(id)
            let rect = bounds.isEmpty ? CGDisplayBounds(CGMainDisplayID()) : bounds
            cachedDisplayRect = rect
            return rect
        case .activeWindow:
            refreshWindowFrameIfStale()
            return windowFrame ?? CGDisplayBounds(CGMainDisplayID())
        }
    }

    private func refreshWindowFrameIfStale() {
        let now = ProcessInfo.processInfo.systemUptime
        guard !isFetchingWindowFrame, now - windowFrameFetchedAt >= Self.windowRefreshInterval,
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        isFetchingWindowFrame = true
        Self.windowQueue.async { [weak self] in
            let frame = Self.focusedWindowFrame(pid: pid)
            DispatchQueue.main.async {
                guard let self else { return }
                self.windowFrame = frame
                self.windowFrameFetchedAt = ProcessInfo.processInfo.systemUptime
                self.isFetchingWindowFrame = false
            }
        }
    }

    private static func focusedWindowFrame(pid: pid_t) -> CGRect? {
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, 0.25)

        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return nil }
        let axWindow = window as! AXUIElement
        AXUIElementSetMessagingTimeout(axWindow, 0.25)

        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// All connected displays as (id, human-readable name), for a settings picker.
    public static func availableDisplays() -> [(id: CGDirectDisplayID, name: String)] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)

        return displayIDs.map { id in
            let name = NSScreen.screens.first { $0.displayID == id }?.localizedName ?? "Display \(id)"
            return (id, name)
        }
    }
}

public extension NSScreen {
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
