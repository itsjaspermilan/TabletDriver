import AppKit
import SwiftUI
import TabletDriverKit
import os

private let appLogger = Logger(subsystem: "com.tabletdriver.app", category: "lifecycle")

let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.tabletdriver.app"

let applicationSupportDirectory: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("TabletDriver", isDirectory: true)
}()

@main
struct TabletDriverApp: App {
    @StateObject private var driver = DriverController(
        applicationSupportDirectory: applicationSupportDirectory
    )
    @State private var hasPermissions = PermissionManager.hasAllPermissions
    @State private var hasStartedDriver = false

    var body: some Scene {
        MenuBarExtra(driver.isConnected ? "Tablet: Connected" : "Tablet: Disconnected", systemImage: "pencil.and.outline") {
            Color.clear.frame(width: 0, height: 0).task {
                // Deliberately not done in `init()`: calling methods on a
                // @StateObject there is a known SwiftUI anti-pattern that can
                // create a second, throwaway instance of `driver` before it's
                // installed on a view -- which meant two separate
                // DeviceMonitors both trying to seize the same HID devices,
                // and crashed with SIGSEGV shortly after launch. `.task` runs
                // once the real, persistent instance is installed.
                guard !hasStartedDriver, hasPermissions else { return }
                hasStartedDriver = true
                driver.start()
                InstallController.installOnFirstRun()
            }
            if hasPermissions {
                Text(driver.isConnected ? "\(driver.activeProfile?.name ?? "Tablet") connected" : "Waiting for tablet…")
                Divider()
                Button("Settings…") {
                    openSettingsWindow(page: .overview)
                }
                Button("Pressure Test…") {
                    openSettingsWindow(page: .pressureTest)
                }
                Button("Uninstall…") {
                    InstallController.uninstall(applicationSupportDirectory: applicationSupportDirectory, bundleIdentifier: bundleIdentifier)
                    NSApplication.shared.terminate(nil)
                }
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            } else {
                Text("Permissions required")
                Button("Open Permission Setup…") {
                    openOnboardingWindow()
                }
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .onChange(of: hasPermissions) { _, granted in
            appLogger.log("hasPermissions changed to \(granted)")
            guard granted, !hasStartedDriver else { return }
            hasStartedDriver = true
            driver.start()
            InstallController.installOnFirstRun()
        }
    }

    init() {
        let granted = PermissionManager.hasAllPermissions
        appLogger.log("app init, hasAllPermissions=\(granted) (input=\(PermissionManager.hasInputMonitoringAccess()), accessibility=\(PermissionManager.hasAccessibilityAccess()))")
    }

    private func openOnboardingWindow() {
        showWindow(id: "onboarding", title: "TabletDriver Setup", size: NSSize(width: 480, height: 440)) {
            OnboardingView(hasPermissions: $hasPermissions)
        }
    }

    private func openSettingsWindow(page: SettingsPage) {
        SettingsNavigator.shared.page = page
        showWindow(id: "settings", title: "TabletDriver", size: NSSize(width: 900, height: 620), resizable: true) {
            SettingsView(driver: driver)
        }
    }

    private func showWindow(id: String, title: String, size: NSSize, resizable: Bool = false, @ViewBuilder content: () -> some View) {
        if let existing = WindowRetainer.shared.window(for: id) {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: resizable
                ? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                : [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = resizable ? .hidden : .visible
        window.center()
        window.title = title
        window.contentView = NSHostingView(rootView: content())
        window.isReleasedWhenClosed = false
        WindowRetainer.shared.retain(window, for: id)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// AppKit adds visible windows to `NSApp.windows`, but that array does not
/// retain them strongly forever, so we hold an explicit strong reference
/// per named window -- and reuse/focus it instead of creating a duplicate
/// when the same window is requested again while already open.
final class WindowRetainer: NSObject, NSWindowDelegate {
    static let shared = WindowRetainer()
    private var windows: [String: NSWindow] = [:]
    private var idsByWindow: [ObjectIdentifier: String] = [:]

    func retain(_ window: NSWindow, for id: String) {
        window.delegate = self
        windows[id] = window
        idsByWindow[ObjectIdentifier(window)] = id
    }

    func window(for id: String) -> NSWindow? {
        windows[id]
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = idsByWindow.removeValue(forKey: ObjectIdentifier(window)) else { return }
        windows.removeValue(forKey: id)
    }
}
