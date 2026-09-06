import AppKit
import SwiftUI
import TabletDriverKit

struct SettingsView: View {
    @ObservedObject var driver: DriverController

    var body: some View {
        TabView {
            GeneralTab(driver: driver)
                .tabItem { Label("General", systemImage: "gearshape") }

            BindingsTab(driver: driver)
                .tabItem { Label("Buttons", systemImage: "square.grid.2x2") }

            TestAreaView(driver: driver)
                .tabItem { Label("Test Area", systemImage: "pencil.tip.crop.circle") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 460)
    }
}

/// A labeled row matching the native macOS Settings look (fixed-width
/// leading label, trailing control), used instead of `Form`'s default
/// layout, which rendered inconsistently in a plain custom window.
private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 130, alignment: .trailing)
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private struct GeneralTab: View {
    @ObservedObject var driver: DriverController
    @State private var clickThresholdPercent: Double
    @State private var mappingSelection: MappingChoice

    init(driver: DriverController) {
        self.driver = driver
        _clickThresholdPercent = State(initialValue: driver.clickThreshold * 100)
        _mappingSelection = State(initialValue: MappingChoice(target: driver.screenMapper.target))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Display Mapping") {
                SettingsRow(label: "Map tablet area to") {
                    Picker("", selection: $mappingSelection) {
                        Text("Active app window").tag(MappingChoice.activeWindow)
                        ForEach(ScreenMapper.availableDisplays(), id: \.id) { display in
                            Text(display.name).tag(MappingChoice.display(display.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                    .onChange(of: mappingSelection) { _, newValue in
                        driver.screenMapper.target = newValue.target
                    }
                }
                Text("\"Active app window\" follows whichever app is frontmost, mapping the full tablet area to that app's window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 138)
            }

            SettingsSection(title: "Pressure") {
                SettingsRow(label: "Click threshold") {
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $clickThresholdPercent, in: 1...100)
                            .frame(width: 220)
                            .onChange(of: clickThresholdPercent) { _, newValue in
                                driver.clickThreshold = newValue / 100
                            }
                        Text("Pressure above \(Int(clickThresholdPercent))% registers as a click.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private enum MappingChoice: Hashable {
        case display(CGDirectDisplayID)
        case activeWindow

        init(target: ScreenMapper.Target) {
            switch target {
            case .activeWindow: self = .activeWindow
            case .display(let id): self = .display(id)
            }
        }

        var target: ScreenMapper.Target {
            switch self {
            case .activeWindow: return .activeWindow
            case .display(let id): return .display(id)
            }
        }
    }
}

private struct BindingsTab: View {
    @ObservedObject var driver: DriverController
    @State private var selectedContext: String = BindingStore.defaultContext

    /// Falls back to a reasonable default so bindings can still be
    /// configured before a tablet is connected.
    private var penButtonCount: Int { driver.activeProfile?.penButtonCount ?? 2 }
    private var expressKeyCount: Int { driver.activeProfile?.auxButtonCount ?? 8 }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("Editing bindings for", selection: $selectedContext) {
                    Text("Default (all apps)").tag(BindingStore.defaultContext)
                    ForEach(driver.bindingStore.appContextOrder, id: \.self) { bundleID in
                        Text(displayName(for: bundleID)).tag(bundleID)
                    }
                }
                .frame(maxWidth: 240)

                Menu("Add App…") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier!) {
                            if let bundleID = app.bundleIdentifier {
                                driver.bindingStore.addAppContext(bundleID)
                                selectedContext = bundleID
                            }
                        }
                    }
                }

                if selectedContext != BindingStore.defaultContext {
                    Button("Remove Override") {
                        driver.bindingStore.removeAppContext(selectedContext)
                        selectedContext = BindingStore.defaultContext
                    }
                }

                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if penButtonCount > 0 {
                        SettingsSection(title: "Pen Buttons") {
                            VStack(spacing: 8) {
                                ForEach(0..<penButtonCount, id: \.self) { index in
                                    BindingRow(
                                        label: "Button \(index + 1)",
                                        action: driver.bindingStore.binding(context: selectedContext, kind: .penButton, index: index),
                                        onChange: { driver.bindingStore.setBinding($0, kind: .penButton, index: index, context: selectedContext) }
                                    )
                                }
                            }
                        }
                    }

                    SettingsSection(title: "Express Keys") {
                        VStack(spacing: 8) {
                            ForEach(0..<expressKeyCount, id: \.self) { index in
                                BindingRow(
                                    label: "Key \(index + 1)",
                                    action: driver.bindingStore.binding(context: selectedContext, kind: .expressKey, index: index),
                                    onChange: { driver.bindingStore.setBinding($0, kind: .expressKey, index: index, context: selectedContext) }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                .frame(width: 60, alignment: .leading)
                .foregroundStyle(.secondary)

            ShortcutRecorderButton(action: action, onCapture: onChange)
                .frame(width: 160)

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

private struct AboutTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            Text("TabletDriver")
                .font(.title2)
                .bold()
            Text("Version \(appVersion)")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("A fully native, Apple Silicon-only macOS driver for XP-Pen tablets, built as an open-source alternative to XP-Pen's official driver.")
                Text("Device support, HID report parsing, and the macOS permission approach are ported from [OpenTabletDriver](https://github.com/OpenTabletDriver/OpenTabletDriver) (LGPL-3.0).")
            }
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 360)

            Link("View on GitHub", destination: URL(string: "https://github.com/itsjaspermilan/TabletDriver")!)
                .font(.callout)

            Spacer(minLength: 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
