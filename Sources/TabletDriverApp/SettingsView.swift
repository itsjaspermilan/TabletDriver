import SwiftUI
import TabletDriverKit

enum SettingsPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case buttons = "Buttons"
    case pressureTest = "Pressure Test"
    case about = "About"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "slider.horizontal.3"
        case .buttons: return "square.grid.2x2"
        case .pressureTest: return "scribble.variable"
        case .about: return "info.circle"
        }
    }
}

final class SettingsNavigator: ObservableObject {
    static let shared = SettingsNavigator()
    @Published var page: SettingsPage = .overview
}

struct SettingsView: View {
    @ObservedObject var driver: DriverController
    @ObservedObject private var navigator = SettingsNavigator.shared

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: Binding<SettingsPage?>(
                get: { navigator.page },
                set: { if let page = $0 { navigator.page = page } }
            )) { page in
                Label(page.rawValue, systemImage: page.systemImage)
                    .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            ZStack {
                AmbientBackground()
                switch navigator.page {
                case .overview: OverviewPage(driver: driver)
                case .buttons: ButtonsPage(driver: driver)
                case .pressureTest: PressureTestView(driver: driver)
                case .about: AboutPage()
                }
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}
