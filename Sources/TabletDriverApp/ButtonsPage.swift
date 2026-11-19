import AppKit
import SwiftUI
import TabletDriverKit

struct ButtonsPage: View {
    let driver: DriverController
    // `driver.bindingStore` is its own ObservableObject nested inside
    // `driver` -- its @Published changes don't propagate through `driver`'s
    // own observation, so this view needs to observe it directly or rows
    // never visually update after recording a shortcut (the binding is
    // still saved correctly; only the displayed label goes stale).
    @ObservedObject private var bindingStore: BindingStore
    @State private var selectedContext: String = BindingStore.defaultContext

    init(driver: DriverController) {
        self.driver = driver
        self.bindingStore = driver.bindingStore
    }

    private var penButtonCount: Int { driver.activeProfile?.penButtonCount ?? 2 }
    private var expressKeyCount: Int { driver.activeProfile?.auxButtonCount ?? 8 }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        PageScaffold(title: "Buttons") {
            contextBar

            if penButtonCount > 0 {
                CardSection(title: "Pen Buttons", systemImage: "pencil.tip") {
                    ForEach(0..<penButtonCount, id: \.self) { index in
                        bindingRow(label: "Button \(index + 1)", kind: .penButton, index: index)
                    }
                }
            }

            CardSection(title: "Express Keys", systemImage: "keyboard") {
                ForEach(0..<expressKeyCount, id: \.self) { index in
                    bindingRow(label: "Key \(index + 1)", kind: .expressKey, index: index)
                }
            }
        }
    }

    private func bindingRow(label: String, kind: ButtonKind, index: Int) -> some View {
        let isDefaultContext = selectedContext == BindingStore.defaultContext
        let stored = bindingStore.storedBinding(context: selectedContext, kind: kind, index: index)
        let title: String
        if let stored {
            title = KeyCodeNames.description(for: stored)
        } else if isDefaultContext {
            title = KeyCodeNames.description(for: .none)
        } else {
            title = "Default (\(KeyCodeNames.description(for: bindingStore.binding(context: BindingStore.defaultContext, kind: kind, index: index))))"
        }
        return BindingRow(
            label: label,
            title: title,
            canUseDefault: !isDefaultContext && stored != nil,
            onChange: { bindingStore.setBinding($0, kind: kind, index: index, context: selectedContext) },
            onUseDefault: { bindingStore.removeBinding(kind: kind, index: index, context: selectedContext) }
        )
    }

    private var contextBar: some View {
        GlassContainer(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Bindings for", selection: $selectedContext) {
                    Text("Default (all apps)").tag(BindingStore.defaultContext)
                    ForEach(bindingStore.appContextOrder, id: \.self) { bundleID in
                        Text(AppNames.displayName(for: bundleID)).tag(bundleID)
                    }
                }
                .frame(maxWidth: 320)

                Menu("Add App…") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier!) {
                            if let bundleID = app.bundleIdentifier {
                                bindingStore.addAppContext(bundleID)
                                selectedContext = bundleID
                            }
                        }
                    }
                }
                .glassButton()

                if selectedContext != BindingStore.defaultContext {
                    Button("Remove Override") {
                        bindingStore.removeAppContext(selectedContext)
                        selectedContext = BindingStore.defaultContext
                    }
                    .glassButton()
                }

                Spacer()
            }
        }
    }
}

private struct BindingRow: View {
    let label: String
    let title: String
    let canUseDefault: Bool
    let onChange: (ExpressKeyAction) -> Void
    let onUseDefault: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .frame(minWidth: 80, alignment: .leading)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            ShortcutRecorderButton(title: title, onCapture: onChange)
                .glassButton()
                .frame(minWidth: 180)
                .accessibilityLabel(label)

            Spacer()

            Menu {
                if canUseDefault {
                    Button("Use Default") { onUseDefault() }
                }
                Button("Set to None") { onChange(.none) }
                Button("Launch App…") { pickApp() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
            .help("More actions")
            .accessibilityLabel("More actions for \(label)")
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
            onChange(.launchApp(bundleIdentifier: bundleID))
        }
    }
}
