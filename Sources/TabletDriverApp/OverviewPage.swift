import SwiftUI
import TabletDriverKit

struct OverviewPage: View {
    @ObservedObject var driver: DriverController
    @State private var clickThresholdPercent: Double
    @State private var mappingSelection: MappingChoice
    @State private var launchAtLogin = InstallController.isEnabled

    init(driver: DriverController) {
        self.driver = driver
        _clickThresholdPercent = State(initialValue: driver.clickThreshold * 100)
        _mappingSelection = State(initialValue: MappingChoice(target: driver.screenMapper.target))
    }

    var body: some View {
        PageScaffold(title: "Overview") {
            statusCard

            CardSection(title: "Display Mapping", systemImage: "display") {
                Picker("Map tablet area to", selection: $mappingSelection) {
                    Text("Active app window").tag(MappingChoice.activeWindow)
                    ForEach(ScreenMapper.availableDisplays(), id: \.id) { display in
                        Text(display.name).tag(MappingChoice.display(display.id))
                    }
                }
                .onChange(of: mappingSelection) { _, newValue in
                    driver.screenMapper.target = newValue.target
                }
                Text("\"Active app window\" follows whichever app is frontmost and maps the full tablet area to that window.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            CardSection(title: "Click Threshold", systemImage: "hand.tap") {
                HStack {
                    Slider(value: $clickThresholdPercent, in: 1...100)
                        .onChange(of: clickThresholdPercent) { _, newValue in
                            driver.clickThreshold = newValue / 100
                        }
                    Text("\(Int(clickThresholdPercent))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                Text("Pen pressure above this level registers as a click. Use the Pressure Test page to find a comfortable value.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            CardSection(title: "Startup", systemImage: "power") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        InstallController.setEnabled(enabled)
                        launchAtLogin = InstallController.isEnabled
                    }
            }
        }
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
