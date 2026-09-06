import AppKit
import CoreGraphics
import Foundation

/// Wires the HID layer to the output layer: pen reports become cursor
/// moves/clicks, aux/pen-button reports become mapped actions (using
/// whichever app is currently frontmost to pick a per-app override).
public final class DriverController: ObservableObject {
    @Published public private(set) var isConnected = false
    @Published public private(set) var activeProfile: TabletProfile?
    @Published public private(set) var lastPenReport: PenReport?
    @Published public private(set) var lastAuxButtons: [Bool] = []
    @Published public private(set) var lastPenButtons: [Bool] = []

    public let bindingStore: BindingStore
    public let preferences: DriverPreferences
    public var screenMapper: ScreenMapper {
        didSet { preferences.mappingTarget = screenMapper.target }
    }

    private let monitor: DeviceMonitor
    private let cursorPoster: CursorPoster
    private var previousAuxButtons: [Bool] = []
    private var previousPenButtons: [Bool] = []

    public init(applicationSupportDirectory: URL, profiles: [TabletProfile] = TabletProfileRegistry.all) {
        self.bindingStore = BindingStore(applicationSupportDirectory: applicationSupportDirectory)
        let preferences = DriverPreferences(applicationSupportDirectory: applicationSupportDirectory)
        self.preferences = preferences
        self.screenMapper = ScreenMapper(target: preferences.mappingTarget)
        self.cursorPoster = CursorPoster(clickThreshold: preferences.clickThreshold)
        self.monitor = DeviceMonitor(profiles: profiles)

        monitor.onDeviceConnected = { [weak self] profile in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isConnected = true
                self.activeProfile = profile
                self.previousAuxButtons = Array(repeating: false, count: profile.auxButtonCount)
                self.previousPenButtons = Array(repeating: false, count: profile.penButtonCount)
                self.lastAuxButtons = self.previousAuxButtons
                self.lastPenButtons = self.previousPenButtons
            }
        }
        monitor.onDeviceDisconnected = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.cursorPoster.reset()
            }
        }
        monitor.onPenReport = { [weak self] pen in
            guard let self else { return }
            let point = self.screenMapper.map(x: pen.x, y: pen.y)
            self.cursorPoster.post(pen: pen, at: point)
            self.handlePenButtons(pen.penButtons)
            DispatchQueue.main.async { self.lastPenReport = pen }
        }
        monitor.onAuxReport = { [weak self] aux in
            self?.handleAuxReport(aux)
        }
    }

    public func start() {
        monitor.start()
    }

    public func stop() {
        monitor.stop()
    }

    public var clickThreshold: Double {
        get { cursorPoster.clickThreshold }
        set {
            cursorPoster.clickThreshold = newValue
            preferences.clickThreshold = newValue
        }
    }

    private func handleAuxReport(_ aux: AuxReport) {
        guard previousAuxButtons.count == aux.buttons.count else {
            previousAuxButtons = aux.buttons
            return
        }
        // Express keys are typically only reported when something actually
        // changes, but guard anyway: frontmostApplication is a real IPC
        // call, not worth paying for on a report that changed nothing.
        guard aux.buttons != previousAuxButtons else { return }

        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let bindings = bindingStore.bindings(for: frontmostBundleID, kind: .expressKey, count: aux.buttons.count)

        for (index, pressed) in aux.buttons.enumerated() {
            if pressed && !previousAuxButtons[index] {
                ShortcutExecutor.execute(bindings[index])
            }
        }
        previousAuxButtons = aux.buttons
        DispatchQueue.main.async { self.lastAuxButtons = aux.buttons }
    }

    private func handlePenButtons(_ buttons: [Bool]) {
        guard previousPenButtons.count == buttons.count, !buttons.isEmpty else {
            if previousPenButtons.count != buttons.count {
                previousPenButtons = buttons
            }
            return
        }
        // This runs on every pen report -- potentially 100+ Hz while
        // drawing -- so skip the frontmostApplication IPC call and binding
        // lookup entirely unless a button actually changed state.
        guard buttons != previousPenButtons else { return }

        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let bindings = bindingStore.bindings(for: frontmostBundleID, kind: .penButton, count: buttons.count)

        for (index, pressed) in buttons.enumerated() {
            if pressed && !previousPenButtons[index] {
                ShortcutExecutor.execute(bindings[index])
            }
        }
        previousPenButtons = buttons
        DispatchQueue.main.async { self.lastPenButtons = buttons }
    }
}
