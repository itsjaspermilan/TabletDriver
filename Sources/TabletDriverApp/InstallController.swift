import AppKit
import ServiceManagement

/// Registers/unregisters this app as a login item via `SMAppService.mainApp`,
/// and handles full teardown for "Uninstall".
enum InstallController {
    private static let firstRunKey = "didConfigureLoginItem"

    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Enables launch-at-login once on first run only, so turning it off in
    /// Settings isn't silently undone at the next launch.
    static func installOnFirstRun() {
        guard !UserDefaults.standard.bool(forKey: firstRunKey) else { return }
        UserDefaults.standard.set(true, forKey: firstRunKey)
        try? setEnabled(true)
    }

    static func uninstall(applicationSupportDirectory: URL, bundleIdentifier: String) {
        if isEnabled {
            try? SMAppService.mainApp.unregister()
        }
        try? FileManager.default.removeItem(at: applicationSupportDirectory)
        UserDefaults.standard.removeObject(forKey: firstRunKey)
        resetTCCGrants(bundleIdentifier: bundleIdentifier)
    }

    /// Only for a real `.app` bundle -- a `swift run` build's "bundle" is
    /// the build products directory, which must not be trashed.
    static func moveAppToTrash(completion: @escaping () -> Void) {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else { return completion() }
        NSWorkspace.shared.recycle([appURL]) { _, _ in
            DispatchQueue.main.async(execute: completion)
        }
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
