import AppKit
import SwiftUI
import TabletDriverKit

struct ButtonsPage: View {
    @ObservedObject var driver: DriverController
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
                        BindingRow(
                            label: "Button \(index + 1)",
                            action: bindingStore.binding(context: selectedContext, kind: .penButton, index: index),
                            onChange: { bindingStore.setBinding($0, kind: .penButton, index: index, context: selectedContext) }
                        )
                    }
                }
            }

            CardSection(title: "Express Keys", systemImage: "keyboard") {
                ForEach(0..<expressKeyCount, id: \.self) { index in
                    BindingRow(
                        label: "Key \(index + 1)",
                        action: bindingStore.binding(context: selectedContext, kind: .expressKey, index: index),
                        onChange: { bindingStore.setBinding($0, kind: .expressKey, index: index, context: selectedContext) }
                    )
                }
            }
        }
    }

    private var contextBar: some View {
        GlassContainer(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Bindings for", selection: $selectedContext) {
                    Text("Default (all apps)").tag(BindingStore.defaultContext)
                    ForEach(bindingStore.appContextOrder, id: \.self) { bundleID in
                        Text(displayName(for: bundleID)).tag(bundleID)
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

    private func displayName(for bundleID: String) -> String {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?
            .localizedName ?? bundleID
    }
}

private struct BindingRow: View {
    let label: String
    let action: ExpressKeyAction
    let onChange: (ExpressKeyAction) -> Void

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .foregroundStyle(.secondary)

            ShortcutRecorderButton(action: action, onCapture: onChange)
                .glassButton()
                .frame(minWidth: 180)

            Spacer()

            Menu {
                Button("Clear") { onChange(.none) }
                Button("Launch App…") { pickApp() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
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
