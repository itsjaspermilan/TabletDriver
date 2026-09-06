import Foundation

public enum KeyModifier: String, Codable, CaseIterable {
    case command, option, control, shift
}

public enum ExpressKeyAction: Codable, Equatable {
    case none
    case keyboardShortcut(modifiers: [KeyModifier], keyCode: UInt16)
    case launchApp(bundleIdentifier: String)
}

/// Which physical control a binding applies to -- a tablet's express keys
/// and a pen's own side buttons are configured separately since they're
/// different hardware, even though both map to the same `ExpressKeyAction`.
public enum ButtonKind: String, Codable {
    case expressKey
    case penButton
}

/// Persists express-key/pen-button -> action mappings per app (keyed by
/// bundle identifier), with a `defaultContext` used whenever the frontmost
/// app has no override, as JSON under Application Support.
///
/// Bindings are stored sparsely (by index) rather than as fixed-size
/// arrays, so this isn't tied to any one tablet's button count -- a
/// profile with more or fewer buttons just uses more or fewer indices.
public final class BindingStore: ObservableObject {
    public static let defaultContext = "__default__"

    public typealias ContextBindings = [ButtonKind: [Int: ExpressKeyAction]]

    @Published public private(set) var contexts: [String: ContextBindings]
    @Published public private(set) var appContextOrder: [String]

    private let fileURL: URL

    public init(applicationSupportDirectory: URL) {
        self.fileURL = applicationSupportDirectory.appendingPathComponent("bindings.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(StoredBindings.self, from: data) {
            contexts = decoded.contexts
            appContextOrder = decoded.appContextOrder
        } else {
            contexts = [:]
            appContextOrder = []
        }
    }

    /// Bindings to use for the given frontmost app, falling back to
    /// defaults, as an array sized to `count` (missing indices are `.none`).
    public func bindings(for bundleIdentifier: String?, kind: ButtonKind, count: Int) -> [ExpressKeyAction] {
        let byIndex: [Int: ExpressKeyAction]
        if let bundleIdentifier, let overrides = contexts[bundleIdentifier]?[kind] {
            byIndex = overrides
        } else {
            byIndex = contexts[Self.defaultContext]?[kind] ?? [:]
        }
        return (0..<count).map { byIndex[$0] ?? .none }
    }

    public func binding(context: String, kind: ButtonKind, index: Int) -> ExpressKeyAction {
        contexts[context]?[kind]?[index] ?? .none
    }

    public func setBinding(_ action: ExpressKeyAction, kind: ButtonKind, index: Int, context: String) {
        var contextBindings = contexts[context] ?? [:]
        var byIndex = contextBindings[kind] ?? [:]
        byIndex[index] = action
        contextBindings[kind] = byIndex
        contexts[context] = contextBindings
        if context != Self.defaultContext && !appContextOrder.contains(context) {
            appContextOrder.append(context)
        }
        save()
    }

    public func addAppContext(_ bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty,
              bundleIdentifier != Self.defaultContext,
              contexts[bundleIdentifier] == nil else { return }
        contexts[bundleIdentifier] = [:]
        appContextOrder.append(bundleIdentifier)
        save()
    }

    public func removeAppContext(_ bundleIdentifier: String) {
        contexts.removeValue(forKey: bundleIdentifier)
        appContextOrder.removeAll { $0 == bundleIdentifier }
        save()
    }

    private func save() {
        let stored = StoredBindings(contexts: contexts, appContextOrder: appContextOrder)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL)
    }

    private struct StoredBindings: Codable {
        var contexts: [String: ContextBindings]
        var appContextOrder: [String]
    }
}
