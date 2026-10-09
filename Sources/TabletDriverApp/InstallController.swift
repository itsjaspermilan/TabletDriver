import Foundation
import ServiceManagement

/// Registers/unregisters this app as a login item via `SMAppService.mainApp`,
/// and handles full teardown for "Uninstall".
enum InstallController {
    private static let firstRunKey = "didConfigureLoginItem"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    /// Enables launch-at-login once on first run only, so turning it off in
    /// Settings isn't silently undone at the next launch.
    static func installOnFirstRun() {
        guard !UserDefaults.standard.bool(forKey: firstRunKey) else { return }
        UserDefaults.standard.set(true, forKey: firstRunKey)
        setEnabled(true)
    }

    static func uninstall(applicationSupportDirectory: URL, bundleIdentifier: String) {
        if isEnabled {
            try? SMAppService.mainApp.unregister()
        }
        try? FileManager.default.removeItem(at: applicationSupportDirectory)
        UserDefaults.standard.removeObject(forKey: firstRunKey)
        resetTCCGrants(bundleIdentifier: bundleIdentifier)
    }

    private static func resetTCCGrants(bundleIdentifier: String) {
        for service in ["Accessibility", "ListenEvent"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, bundleIdentifier]
            try? process.run()
            process.waitUntilExit()
        }
    }
}
