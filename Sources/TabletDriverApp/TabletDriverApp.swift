import AppKit
import SwiftUI
import TabletDriverKit
import os

private let appLogger = Logger(subsystem: "com.tabletdriver.app", category: "lifecycle")

let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.itsjaspermilan.TabletDriver"

let applicationSupportDirectory: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("TabletDriver", isDirectory: true)
}()

@main
struct TabletDriverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(appDelegate: appDelegate, driver: appDelegate.driver, permissions: appDelegate.permissions)
        } label: {
            MenuBarLabel(driver: appDelegate.driver)
        }
    }
}

private struct MenuBarLabel: View {
    let driver: DriverController

    var body: some View {
        Label(
            driver.isConnected ? "Tablet: Connected" : "Tablet: Disconnected",
            systemImage: driver.isConnected ? "pencil.and.outline" : "pencil.slash"
        )
    }
}

private struct MenuContent: View {
    let appDelegate: AppDelegate
    let driver: DriverController
    let permissions: PermissionStatus

    var body: some View {
        if permissions.allGranted {
            Text(driver.isConnected ? "\(driver.activeProfile?.name ?? "Tablet") connected" : "Waiting for tablet…")
            Divider()
            Button("Settings…") { appDelegate.openSettingsWindow(page: .overview) }
            Button("Pressure Test…") { appDelegate.openSettingsWindow(page: .pressureTest) }
            Button("Uninstall…") { appDelegate.confirmUninstall() }
        } else {
            Text("Permissions required")
            Button("Open Permission Setup…") { appDelegate.openOnboardingWindow() }
        }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}

/// Owns the driver and does launch-time setup. `NSApplicationDelegateAdaptor`
/// instantiates this exactly once, unlike SwiftUI `@State`/`@StateObject`
/// in an `App`, which can be created more than once -- two `DriverController`s
/// meant two `DeviceMonitor`s seizing the same HID device, which crashed.
/// Starting from `applicationDidFinishLaunching` (rather than a `.task` in
/// the menu content) also means the driver runs at login without anyone
/// having to open the menu first.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let driver = DriverController(applicationSupportDirectory: applicationSupportDirectory)
    let permissions = PermissionStatus()
    private var hasStartedDriver = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        appLogger.log("launched, input=\(self.permissions.hasInputMonitoring), accessibility=\(self.permissions.hasAccessibility)")
        if permissions.allGranted {
            startDriver()
        } else {
            openOnboardingWindow()
            permissions.pollUntilGranted { [weak self] in
                guard let self else { return }
                appLogger.log("permissions granted")
                self.startDriver()
                WindowRetainer.shared.window(for: "onboarding")?.close()
                self.openSettingsWindow(page: .overview)
            }
        }
    }

    private func startDriver() {
        guard !hasStartedDriver else { return }
        hasStartedDriver = true
        driver.start()
        InstallController.installOnFirstRun()
    }

    func openOnboardingWindow() {
        showWindow(id: "onboarding", title: "TabletDriver Setup", size: NSSize(width: 480, height: 440)) {
            OnboardingView(permissions: permissions)
        }
    }

    func openSettingsWindow(page: SettingsPage) {
        SettingsNavigator.shared.page = page
        showWindow(id: "settings", title: "TabletDriver", size: NSSize(width: 900, height: 620), resizable: true) {
            SettingsView(driver: driver)
        }
    }

    func confirmUninstall() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Uninstall TabletDriver?"
        alert.informativeText = "This deletes your button bindings and settings, turns off launch at login, resets TabletDriver's Input Monitoring and Accessibility permissions, and moves the app to the Trash."
        alert.addButton(withTitle: "Uninstall").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        driver.stop()
        InstallController.uninstall(applicationSupportDirectory: applicationSupportDirectory, bundleIdentifier: bundleIdentifier)
        InstallController.moveAppToTrash {
            NSApplication.shared.terminate(nil)
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
        window.title = title
        // Each page sets its own `.navigationTitle`, which the hosting
        // controller bridges into this window's real titlebar/toolbar.
        // Using a controller (not a bare hosting view as contentView) lets
        // AppKit lay out the traffic lights and titlebar like a SwiftUI scene.
        let controller = NSHostingController(rootView: content())
        // Without this the hosting controller re-derives the window's
        // min/max size from its content on every layout pass, which fights
        // the sidebar expand animation (content slides, then snaps).
        controller.sizingOptions = []
        window.contentViewController = controller
        window.setContentSize(size)
        window.center()
        if resizable { window.contentMinSize = NSSize(width: 760, height: 540) }
        window.isReleasedWhenClosed = false
        WindowRetainer.shared.retain(window, for: id)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// Live Input Monitoring/Accessibility state. Polled while anything is
/// missing, since macOS posts no notification when either is granted in
/// System Settings -- and it's polled from launch, not just while the
/// setup window is open, so granting them with that window closed still
/// starts the driver.
@MainActor
@Observable
final class PermissionStatus {
    private(set) var hasInputMonitoring = PermissionManager.hasInputMonitoringAccess()
    private(set) var hasAccessibility = PermissionManager.hasAccessibilityAccess()
    @ObservationIgnored private var timer: Timer?

    var allGranted: Bool { hasInputMonitoring && hasAccessibility }

    func pollUntilGranted(onGranted: @escaping @MainActor () -> Void) {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.hasInputMonitoring = PermissionManager.hasInputMonitoringAccess()
                self.hasAccessibility = PermissionManager.hasAccessibilityAccess()
                guard self.allGranted else { return }
                timer.invalidate()
                self.timer = nil
                onGranted()
            }
        }
        // `.common` so the poll keeps running while the menu bar menu is
        // open (menu tracking switches the run loop out of the default mode).
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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
