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

    public static func requestInputMonitoringAccess() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
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
