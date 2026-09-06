import Foundation
import ServiceManagement

/// Registers/unregisters this app as a login item (the "service install")
/// via `SMAppService.mainApp`, and handles full teardown for "Uninstall".
enum InstallController {
    static func install() throws {
        if SMAppService.mainApp.status != .enabled {
            try SMAppService.mainApp.register()
        }
    }

    static func uninstall(applicationSupportDirectory: URL, bundleIdentifier: String) {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        }
        try? FileManager.default.removeItem(at: applicationSupportDirectory)
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
