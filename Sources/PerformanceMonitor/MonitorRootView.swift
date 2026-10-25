import SwiftUI

enum MonitorTab: String, CaseIterable, Identifiable {
    case processes = "Processos"
    case performance = "Performance"
    var id: Self { self }
}

struct MonitorRootView: View {
    @ObservedObject var metrics: Metrics
    @ObservedObject var processes: ProcessMetrics
    @AppStorage("monitorTab") private var tab: MonitorTab = .processes
    var body: some View {
        Group {
            if tab == .performance { PerformanceView(metrics: metrics) }
            else { ProcessesView(metrics: metrics, store: processes) }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(L("Área do monitor"), selection: $tab) {
                    ForEach(MonitorTab.allCases) { Text(L10n.text($0.rawValue)).tag($0) }
                }.pickerStyle(.segmented).frame(width: 240)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink { Label(L("Ajustes"), systemImage: "gearshape") }.help(L("Idioma e ajustes do aplicativo"))
            }
        }
        .task(id: "\(tab.rawValue):\(metrics.paused)") {
            processes.resetBaseline()
            guard tab == .processes, !metrics.paused else { return }
            while !Task.isCancelled {
                await processes.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
            }
        }
    }
}
