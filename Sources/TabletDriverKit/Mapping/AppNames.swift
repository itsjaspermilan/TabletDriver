import AppKit

/// Human-readable app names for bundle identifiers, whether or not the app
/// is currently running. Falls back to the bundle identifier itself.
public enum AppNames {
    public static func displayName(for bundleIdentifier: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let name = running.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let name = FileManager.default.displayName(atPath: url.path)
            return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
        }
        return bundleIdentifier
    }
}
