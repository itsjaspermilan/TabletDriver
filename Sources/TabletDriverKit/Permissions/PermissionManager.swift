import AppKit
import ApplicationServices
import Foundation
import IOKit.hid

/// Port of OpenTabletDriver's `PermissionHelper` (OpenTabletDriver.UX.MacOS)
/// using the same underlying IOKit/ApplicationServices calls: Input
/// Monitoring is checked/requested via `IOHIDCheckAccess`/`IOHIDRequestAccess`,
/// Accessibility via `AXIsProcessTrusted`/`AXIsProcessTrustedWithOptions`.
public enum PermissionManager {
    public static func hasInputMonitoringAccess() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Unlike Accessibility, `IOHIDRequestAccess` has proven unreliable here
    /// at actually surfacing the native approve/deny prompt (confirmed: it's
    /// a no-op even right after resetting this app's TCC entry with
    /// `tccutil reset ListenEvent`). Call it anyway in case it does show the
    /// prompt, then send the user to System Settings to add/enable the app
    /// by hand regardless — `OnboardingView` shows a note next to this
    /// permission telling them to do so.
    public static func requestInputMonitoringAccess() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    public static func hasAccessibilityAccess() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system Accessibility permission dialog if not already granted.
    public static func requestAccessibilityAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options: NSDictionary = [key: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public static var hasAllPermissions: Bool {
        hasInputMonitoringAccess() && hasAccessibilityAccess()
    }
}
