import CoreGraphics
import AppKit

/// Executes an `ExpressKeyAction` — posts a keyboard shortcut via CGEvent
/// or launches an app, mirroring the express-key handling users expect
/// from Wacom/XP-Pen's own control panels.
public enum ShortcutExecutor {
    public static func execute(_ action: ExpressKeyAction) {
        switch action {
        case .none:
            break
        case let .keyboardShortcut(modifiers, keyCode):
            postKeyboardShortcut(modifiers: modifiers, keyCode: keyCode)
        case let .launchApp(bundleIdentifier):
            launchApp(bundleIdentifier: bundleIdentifier)
        }
    }

    private static func postKeyboardShortcut(modifiers: [KeyModifier], keyCode: UInt16) {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else { return }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func launchApp(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
