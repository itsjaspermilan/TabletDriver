import SwiftUI
import TabletDriverKit

struct OnboardingView: View {
    @Binding var hasPermissions: Bool
    @State private var hasInputMonitoring = PermissionManager.hasInputMonitoringAccess()
    @State private var hasAccessibility = PermissionManager.hasAccessibilityAccess()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tablet Driver needs two permissions to receive input from the tablet and move the cursor.")
                .font(.headline)

            permissionRow(
                title: "Input Monitoring",
                granted: hasInputMonitoring,
                action: { PermissionManager.requestInputMonitoringAccess() }
            )

            permissionRow(
                title: "Accessibility",
                granted: hasAccessibility,
                action: { PermissionManager.requestAccessibilityAccess() }
            )

            Spacer()
            Text("This window updates automatically once both permissions are granted in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .onReceive(timer) { _ in
            hasInputMonitoring = PermissionManager.hasInputMonitoringAccess()
            hasAccessibility = PermissionManager.hasAccessibilityAccess()
            hasPermissions = hasInputMonitoring && hasAccessibility
        }
    }

    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
            Spacer()
            if !granted {
                Button("Grant…", action: action)
            }
        }
    }
}
