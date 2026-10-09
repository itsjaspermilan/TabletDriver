import SwiftUI

struct AboutPage: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            }

            VStack(spacing: 4) {
                Text("TabletDriver").font(.title.weight(.bold))
                Text("Version \(appVersion)").foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("A fully native, Apple Silicon macOS driver for graphics tablets — an open-source alternative to vendor drivers.")
                Text("Device support, HID report parsing and the macOS pressure technique are ported from [OpenTabletDriver](https://github.com/OpenTabletDriver/OpenTabletDriver) (LGPL-3.0).")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: 420)
            .glassCard()

            Link("View on GitHub", destination: URL(string: "https://github.com/itsjaspermilan/TabletDriver")!)
                .glassButton()

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
}
