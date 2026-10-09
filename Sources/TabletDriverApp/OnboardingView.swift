import Combine
import SwiftUI
import TabletDriverKit

struct OnboardingView: View {
    @Binding var hasPermissions: Bool
    @State private var hasInputMonitoring = PermissionManager.hasInputMonitoringAccess()
    @State private var hasAccessibility = PermissionManager.hasAccessibilityAccess()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 20) {
                if let icon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 84, height: 84)
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                }
                VStack(spacing: 4) {
                    Text("Welcome to TabletDriver").font(.title2.weight(.bold))
                    Text("Two permissions are needed to read your tablet and move the cursor.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                GlassContainer {
                    VStack(spacing: 12) {
                        permissionRow(
                            title: "Input Monitoring",
                            detail: "Reads pen and button data from the tablet",
                            symbol: "dot.radiowaves.left.and.right",
                            granted: hasInputMonitoring,
                            note: hasInputMonitoring ? nil : "If TabletDriver isn't listed in the settings page that opens, click + and add it yourself, then enable its checkbox.",
                            action: { PermissionManager.requestInputMonitoringAccess() }
                        )
                        permissionRow(
                            title: "Accessibility",
                            detail: "Moves the cursor and presses shortcuts",
                            symbol: "accessibility",
                            granted: hasAccessibility,
                            note: nil,
                            action: { PermissionManager.requestAccessibilityAccess() }
                        )
                    }
                }

                Text("This window updates automatically once both are granted in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .onReceive(timer) { _ in
            hasInputMonitoring = PermissionManager.hasInputMonitoringAccess()
            hasAccessibility = PermissionManager.hasAccessibilityAccess()
            hasPermissions = hasInputMonitoring && hasAccessibility
        }
    }

    private func permissionRow(title: String, detail: String, symbol: String, granted: Bool, note: String?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Button("Grant…", action: action)
                        .glassButton(prominent: true)
                }
            }
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 46)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }
}
