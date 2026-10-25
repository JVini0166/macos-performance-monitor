import SwiftUI

enum MonitorTab: String, CaseIterable, Identifiable {
    case processes = "Processos"
    case performance = "Performance"
    var id: Self { self }
}

struct MonitorRootView: View {
    @ObservedObject var metrics: Metrics
    @StateObject private var processes = ProcessMetrics()
    @State private var tab: MonitorTab = .processes
    var body: some View {
        Group {
            if tab == .performance { PerformanceView(metrics: metrics) }
            else { ProcessesView(metrics: metrics, store: processes) }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Área do monitor", selection: $tab) {
                    ForEach(MonitorTab.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 240)
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
