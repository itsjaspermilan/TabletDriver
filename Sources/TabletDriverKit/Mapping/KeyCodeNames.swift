import Foundation

/// Best-effort virtual keyCode -> display name, for showing recorded
/// shortcuts and presets in the UI. Covers common keys; anything missing
/// falls back to "Key <code>".
public enum KeyCodeNames {
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        50: "`",
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    public static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    public static func symbol(for modifier: KeyModifier) -> String {
        switch modifier {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    public static func description(modifiers: [KeyModifier], keyCode: UInt16) -> String {
        let orderedModifiers: [KeyModifier] = [.control, .option, .shift, .command]
        let prefix = orderedModifiers.filter(modifiers.contains).map(symbol(for:)).joined()
        return prefix + name(for: keyCode)
    }

    public static func description(for action: ExpressKeyAction) -> String {
        switch action {
        case .none:
            return "None"
        case let .keyboardShortcut(modifiers, keyCode):
            return description(modifiers: modifiers, keyCode: keyCode)
        case let .launchApp(bundleIdentifier):
            return "Launch " + bundleIdentifier
        }
    }
}
