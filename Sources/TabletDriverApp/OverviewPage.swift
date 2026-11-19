import ServiceManagement
import SwiftUI
import TabletDriverKit

struct OverviewPage: View {
    let driver: DriverController
    @State private var thresholdPosition: Double
    @State private var mappingSelection: MappingChoice
    @State private var displays = ScreenMapper.availableDisplays()
    @State private var loginItemStatus = InstallController.status
    @State private var loginItemError: String?

    init(driver: DriverController) {
        self.driver = driver
        _thresholdPosition = State(initialValue: ClickThresholdScale.position(for: driver.clickThreshold))
        _mappingSelection = State(initialValue: MappingChoice(target: driver.screenMapper.target))
    }

    private var thresholdLabel: String {
        ClickThresholdScale.label(for: ClickThresholdScale.threshold(at: thresholdPosition))
    }

    private var isSelectedDisplayMissing: Bool {
        guard case .display(let id) = mappingSelection else { return false }
        return !displays.contains { $0.id == id }
    }

    var body: some View {
        PageScaffold(title: "Overview") {
            statusCard

            CardSection(title: "Display Mapping", systemImage: "display") {
                Picker("Map tablet area to", selection: $mappingSelection) {
                    Text("Active app window").tag(MappingChoice.activeWindow)
                    ForEach(displays, id: \.id) { display in
                        Text(display.name).tag(MappingChoice.display(display.id))
                    }
                    if isSelectedDisplayMissing {
                        Text("Disconnected display (using main display)").tag(mappingSelection)
                    }
                }
                .onChange(of: mappingSelection) { _, newValue in
                    driver.screenMapper.target = newValue.target
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                    displays = ScreenMapper.availableDisplays()
                }
                Text("\"Active app window\" follows whichever app is frontmost and maps the full tablet area to that window.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            CardSection(title: "Click Threshold", systemImage: "hand.tap") {
                HStack {
                    Slider(value: $thresholdPosition, in: 0...1) {
                        Text("Click threshold")
                    }
                    .labelsHidden()
                    .accessibilityValue(thresholdLabel)
                    .onChange(of: thresholdPosition) { _, newValue in
                        driver.clickThreshold = ClickThresholdScale.threshold(at: newValue)
                    }
                    Text(thresholdLabel)
                        .monospacedDigit()
                        .frame(minWidth: 52, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                Text("Pen pressure above this level registers as a click. Use the Pressure Test page to find a comfortable value.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            CardSection(title: "Startup", systemImage: "power") {
                Toggle("Launch at login", isOn: Binding(
                    get: { loginItemStatus == .enabled || loginItemStatus == .requiresApproval },
                    set: setLaunchAtLogin
                ))
                if loginItemStatus == .requiresApproval {
                    HStack {
                        Text("macOS needs you to allow TabletDriver in Login Items before it can start at login.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                            .glassButton()
                    }
                }
                if let loginItemError {
                    Label(loginItemError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                loginItemStatus = InstallController.status
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try InstallController.setEnabled(enabled)
            loginItemError = nil
        } catch {
            loginItemError = "Couldn't \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
        }
        loginItemStatus = InstallController.status
    }

    private var statusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(driver.isConnected ? Color.green.opacity(0.25) : Color.secondary.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: driver.isConnected ? "pencil.tip.crop.circle.badge.checkmark" : "pencil.tip.crop.circle.badge.questionmark")
                    .font(.system(size: 26))
                    .foregroundStyle(driver.isConnected ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(driver.isConnected ? (driver.activeProfile?.name ?? "Tablet") : "No tablet connected")
                    .font(.title3.weight(.semibold))
                Text(driver.isConnected ? "Connected and ready" : "Plug in your tablet — it will be picked up automatically")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: driver.isConnected ? .green : nil)
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
