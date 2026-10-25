import SwiftUI
import AppKit

@main struct PerformanceMonitorApp: App {
    @StateObject private var metrics = Metrics()
    @StateObject private var processes = ProcessMetrics()
    @AppStorage(L10n.preferenceKey) private var language = AppLanguage.initial.rawValue
    var body: some Scene {
        WindowGroup("Performance Monitor") {
            MonitorRootView(metrics: metrics, processes: processes)
                .environment(\.locale, Locale(identifier: language))
                .id(language)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1260, height: 790)
        .windowToolbarStyle(.unified)
        .commands { CommandGroup(after: .newItem) {
            Button(metrics.paused ? L("Retomar gráficos") : L("Pausar gráficos")) { metrics.paused.toggle() }.keyboardShortcut("p", modifiers: [.command])
        }
            CommandGroup(replacing: .appSettings) {
                SettingsLink { Text(L("Ajustes…")) }.keyboardShortcut(",", modifiers: .command)
            }
        }
        Settings { LanguageSettingsView() }
    }
}

extension Resource {
    var color: Color {
        switch self {
        case .cpu: return Color(red: 0.20, green: 0.72, blue: 0.83)
        case .memory: return Color(red: 0.57, green: 0.57, blue: 0.91)
        case .disk: return Color(red: 0.35, green: 0.76, blue: 0.65)
        case .gpu: return Color(red: 0.70, green: 0.54, blue: 0.85)
        case .network: return Color(red: 0.86, green: 0.57, blue: 0.75)
        }
    }
}

struct PerformanceView: View {
    @ObservedObject var metrics: Metrics
    @AppStorage("selectedResource") private var selection: Resource = .cpu
    @AppStorage("logicalProcessors") private var logicalProcessors = false
    @AppStorage("showKernelTimes") private var showKernelTimes = false
    var body: some View {
        NavigationSplitView {
            List(selection: Binding<String?>(get: {
                selection == .disk && !metrics.selectedDiskID.isEmpty ? "disk:" + metrics.selectedDiskID : selection.rawValue
            }, set: { value in
                guard let value else { return }
                if value.hasPrefix("disk:") {
                    metrics.selectedDiskID = String(value.dropFirst(5))
                    selection = .disk
                } else if let resource = Resource(rawValue: value) { selection = resource }
            })) {
                Section(L("Recursos do sistema")) {
                    ForEach(Resource.allCases) { resource in
                        if resource == .disk && !metrics.disks.isEmpty {
                            ForEach(Array(metrics.disks.enumerated()), id: \.element.id) { index, disk in
                                resourceRow(.disk, title: L("Disco \(index)"),
                                            subtitle: metrics.diskRates[disk.id].map { L10n.number(L("%.0f%% de atividade"), $0.activeEstimate) } ?? L("Aguardando I/O"),
                                            values: metrics.diskHistory[disk.id] ?? [])
                                    .tag("disk:" + disk.id)
                            }
                        } else {
                            resourceRow(resource, title: resource.rawValue, subtitle: metrics.subtitle(resource),
                                        values: resource == .gpu ? metrics.gpuHistory(.overall) : metrics.history[resource] ?? [])
                                .tag(resource.rawValue)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Performance Monitor")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Image(systemName: "desktopcomputer").font(.title3).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metrics.processor).font(.system(size: 11, weight: .medium))
                        Text(L("\(metrics.logical) processadores · \(Metrics.bytes(metrics.memoryTotal)) RAM"))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(16)
            }
        } detail: {
            Group {
                if selection == .gpu { GPUPerformanceView(metrics: metrics) }
                else { detail }
            }
            .padding(.horizontal, 28)
            .background {
                ZStack(alignment: .topTrailing) {
                    Color(nsColor: .windowBackgroundColor)
                    RadialGradient(colors: [selection.color.opacity(0.07), .clear], center: .topTrailing, startRadius: 0, endRadius: 650)
                }.ignoresSafeArea()
            }
            .navigationTitle(L10n.text(panelTitle))
            .navigationSubtitle(L("Monitor de Performance"))
            .toolbar {
                ToolbarItem(placement: .status) { LiveStatus(paused: metrics.paused) }
                ToolbarItem(placement: .primaryAction) {
                    Button { metrics.paused.toggle() } label: {
                        Label(metrics.paused ? L("Retomar") : L("Pausar"), systemImage: metrics.paused ? "play.fill" : "pause.fill")
                    }.help(L("Pausar ou retomar os gráficos (⌘P)"))
                }
            }
        }
        .tint(.accentColor)
    }
    var panelTitle: String {
        guard selection == .disk, let index = metrics.disks.firstIndex(where: { $0.id == metrics.selectedDiskID }) else { return L10n.text(selection.rawValue) }
        return L("Disco \(index)")
    }
    func resourceRow(_ resource: Resource, title: String, subtitle: String, values: [Double]) -> some View {
        HStack(spacing: 11) {
            Image(systemName: resource.symbol).font(.system(size: 16, weight: .medium))
                .foregroundStyle(resource.color).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text(title)).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).monospacedDigit()
            }
            Spacer(minLength: 0)
            HistoryGraph(values: values, color: resource.color, maximum: maximum(resource), grid: false)
                .frame(width: 46, height: 26).accessibilityHidden(true)
        }.padding(.vertical, 10)
    }
    func maximum(_ resource: Resource) -> Double {
        resource == .network ? max(1024, (metrics.history[.network] ?? []).max() ?? 0) * 1.15 : 100
    }
    var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.text(panelTitle)).font(.system(size: 28, weight: .semibold, design: .rounded))
                    Spacer(minLength: 16)
                    Text(detailTitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.trailing)
                }.padding(.top, 24).padding(.bottom, 24)
                HStack {
                    Text(graphLabel)
                    Spacer()
                    if selection == .cpu {
                        Menu {
                            cpuGraphOptions
                        } label: { Image(systemName: "square.grid.2x2") }
                        .menuStyle(.borderlessButton).fixedSize().help(L("Alterar gráfico da CPU; também disponível com clique direito"))
                    }
                    Text(selection == .network ? "\(Metrics.bytes(maximum(selection)))/s" : selection == .memory ? Metrics.bytes(metrics.memoryTotal) : "100%")
                }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 5)
                Group {
                    if selection == .cpu && logicalProcessors {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: coreColumns), spacing: 10) {
                            ForEach(metrics.coreHistory.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack { Text("CPU \(index)"); Spacer(); Text(L10n.number("%.0f%%", metrics.coreUsage[index])) }.font(.system(size: 10)).foregroundStyle(.secondary)
                                    ZStack {
                                        HistoryGraph(values: metrics.coreHistory[index], color: selection.color, maximum: 100, grid: true)
                                        if showKernelTimes {
                                            HistoryGraph(values: metrics.coreKernelHistory[index], color: .primary.opacity(0.65), maximum: 100, grid: false, filled: false, dashed: true)
                                        }
                                    }
                                }.padding(10).frame(height: coreHeight + 20).background(selection.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    } else {
                        ZStack {
                            HistoryGraph(values: selection == .disk ? metrics.diskHistory[metrics.selectedDiskID] ?? [] : metrics.history[selection] ?? [], color: selection.color, maximum: maximum(selection), grid: true)
                            if selection == .cpu && showKernelTimes {
                                HistoryGraph(values: metrics.kernelHistory, color: .primary.opacity(0.65), maximum: 100, grid: false, filled: false, dashed: true)
                            }
                        }.frame(height: selection == .disk ? 165 : selection == .memory ? 220 : 300)
                    }
                }.padding(16).monitorSurface().contextMenu {
                    if selection == .cpu {
                        Menu(L("Alterar gráfico para")) { cpuGraphOptions }
                        Toggle(L("Mostrar tempos do kernel"), isOn: $showKernelTimes)
                        Divider()
                        Button(L("Copiar resumo")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(L("CPU: \(metrics.processor)\nUtilização: \(metrics.subtitle(.cpu))\nNúcleos: \(metrics.cores)\nProcessadores lógicos: \(metrics.logical)"), forType: .string)
                        }
                    }
                }
                HStack { Text(L("60 segundos")); Spacer(); Text("0") }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 6)
                if selection == .disk { diskTransferGraph.padding(.top, 16) }
                if selection == .memory { memoryComposition.padding(.top, 16) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: statistics.count > 4 ? 3 : max(1, statistics.count)), alignment: .leading, spacing: 14) {
                    ForEach(statistics, id: \.0) { entry in statistic(entry.0, entry.1) }
                }.padding(.top, 22)
                Color.clear.frame(height: 20)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(details, id: \.0) { entry in
                        HStack(alignment: .top) {
                            Text(L10n.text(entry.0)).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                            Text(entry.1).textSelection(.enabled)
                        }.font(.system(size: 12))
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading).monitorSurface()
                Text(footnote).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 18).padding(.bottom, 20)
            }
        }
    }
    var coreColumns: Int { metrics.logical <= 4 ? 2 : metrics.logical <= 16 ? 4 : 8 }
    var coreHeight: CGFloat { metrics.logical <= 16 ? 85 : 65 }
    @ViewBuilder var cpuGraphOptions: some View {
        Button { logicalProcessors = false } label: { Label(L("Utilização geral"), systemImage: logicalProcessors ? "circle" : "checkmark.circle.fill") }
        Button { logicalProcessors = true } label: { Label(L("Processadores lógicos"), systemImage: logicalProcessors ? "checkmark.circle.fill" : "circle") }
    }
    var diskTransferMaximum: Double {
        max(1_048_576, max((metrics.diskReadHistory[metrics.selectedDiskID] ?? []).max() ?? 0, (metrics.diskWriteHistory[metrics.selectedDiskID] ?? []).max() ?? 0) * 1.15)
    }
    var diskTransferGraph: some View {
        VStack(spacing: 5) {
            HStack { Text(L("Taxa de transferência do disco")); Spacer(); Text("\(Metrics.bytes(diskTransferMaximum))/s") }.font(.system(size: 11)).foregroundStyle(.secondary)
            ZStack {
                HistoryGraph(values: metrics.diskReadHistory[metrics.selectedDiskID] ?? [], color: Resource.disk.color, maximum: diskTransferMaximum, grid: true, filled: false)
                HistoryGraph(values: metrics.diskWriteHistory[metrics.selectedDiskID] ?? [], color: Resource.disk.color.opacity(0.7), maximum: diskTransferMaximum, grid: false, filled: false, dashed: true)
            }.frame(height: 95)
            HStack { Text(L("60 segundos")); Spacer(); Text(L("— Leitura    ┄ Escrita")) }.font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(16).monitorSurface()
    }
    var memoryComposition: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L("Composição da memória")).font(.system(size: 11)).foregroundStyle(.secondary)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    compositionSegment(L("Apps (estimativa)"), metrics.memoryApps, 0.75, geometry.size.width)
                    compositionSegment("Wired", metrics.memoryWired, 1, geometry.size.width)
                    compositionSegment(L("Comprimida"), metrics.memoryCompressed, 0.5, geometry.size.width)
                    compositionSegment(L("Disponível"), metrics.memoryAvailable, 0.08, geometry.size.width)
                }
            }.frame(height: 24).clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Resource.memory.color.opacity(0.3), lineWidth: 0.5))
            Text(L("Apps · Wired · Comprimida · Disponível")).font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(16).monitorSurface()
    }
    func compositionSegment(_ label: String, _ value: Double, _ opacity: Double, _ width: CGFloat) -> some View {
        Rectangle().fill(Resource.memory.color.opacity(opacity)).frame(width: width * value / metrics.memoryTotal)
            .help("\(label): \(Metrics.bytes(value))")
    }
    func statistic(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text(label)).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 24, weight: .medium, design: .rounded)).monospacedDigit().textSelection(.enabled)
        }.padding(16).frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading).monitorSurface()
    }
    var graphLabel: String {
        switch selection {
        case .cpu: return logicalProcessors ? L("Utilização por processador lógico") : L("% Utilização")
        case .memory: return L("Uso da memória física")
        case .disk: return L("% Tempo ativo")
        case .gpu: return L("% Utilização")
        case .network: return L("Taxa de transferência")
        }
    }
    var detailTitle: String {
        switch selection {
        case .cpu: return metrics.processor
        case .memory: return L("\(Metrics.bytes(metrics.memoryTotal)) de memória física")
        case .disk: return metrics.selectedDisk?.name ?? L("Disco indisponível")
        case .gpu: return metrics.selectedGPU?.name ?? L("GPU indisponível")
        case .network: return L("Interfaces de rede · Total agregado")
        }
    }
    var statistics: [(String, String)] {
        let bytes = Metrics.bytes
        switch selection {
        case .cpu: return [(L("Utilização"), metrics.subtitle(.cpu)), (L("Tempo de atividade"), metrics.uptime), (L("Temperatura (máxima)"), TemperatureReading.formatted(metrics.cpuTemperature))]
        case .memory: return [
            (L("Em uso (comprimida)"), "\(bytes(metrics.memoryUsed)) (\(bytes(metrics.memoryCompressed)))"),
            (L("Disponível (estimativa)"), bytes(metrics.memoryAvailable)),
            (L("Em cache (estimativa)"), bytes(metrics.memoryCached)),
            (L("Swap usado"), bytes(metrics.swapUsed)),
            (L("Swap alocado"), bytes(metrics.swapTotal)),
            (L("Wired (não paginável)"), bytes(metrics.memoryWired))]
        case .disk:
            let rate = metrics.selectedDiskRates
            return [(L("Tempo ativo"), rate.map { L10n.number("%.1f%%", $0.activeEstimate) } ?? "—"),
                    (L("Tempo médio de I/O"), rate?.responseMS.map { L10n.number("%.2f ms", $0) } ?? "—"),
                    (L("Velocidade de leitura"), rate.map { "\(bytes($0.read))/s" } ?? "—"),
                    (L("Velocidade de escrita"), rate.map { "\(bytes($0.write))/s" } ?? "—")]
        case .gpu: return []
        case .network: return [(L("Recebimento"), "\(bytes(metrics.received))/s"), (L("Envio"), "\(bytes(metrics.sent))/s")]
        }
    }
    var details: [(String, String)] {
        let bytes = Metrics.bytes
        switch selection {
        case .cpu: return [(L("Núcleos:"), "\(metrics.cores)"), (L("Processadores lógicos:"), "\(metrics.logical)"), (L("Arquitetura:"), Metrics.sysString("hw.machine")), (L("Frequência atual:"), L("Não disponível")), (L("Sensores térmicos:"), metrics.cpuTemperature.map { "AppleSMC · " + $0.sensors.joined(separator: ", ") } ?? L("Indisponíveis neste hardware"))]
        case .memory: return [(L("Memória física:"), bytes(metrics.memoryTotal)), (L("Apps (estimativa):"), bytes(metrics.memoryApps)),
                              (L("Livre:"), bytes(metrics.memoryFree)), (L("Swap disponível:"), bytes(max(0, metrics.swapTotal - metrics.swapUsed))),
                              (L("Swap de entrada:"), "\(bytes(metrics.swapIn))/s"), (L("Swap de saída:"), "\(bytes(metrics.swapOut))/s")]
        case .disk: return [(L("Disco físico:"), metrics.selectedDisk?.id ?? "—"),
                            (L("Capacidade:"), metrics.selectedDisk.map { bytes($0.capacity) } ?? "—"),
                            (L("Conexão:"), metrics.selectedDisk?.connection ?? "—"),
                            (L("Operações por segundo:"), metrics.selectedDiskRates.map { L10n.number("%.0f IOPS", $0.operations) } ?? "—")]
        case .gpu: return []
        case .network: return [(L("Escopo:"), L("Interfaces sem loopback")), (L("Unidade:"), L("Bytes por segundo"))]
        }
    }
    var footnote: String {
        switch selection {
        case .disk: return L("Atividade estimada pela soma dos tempos de I/O ÷ intervalo, limitada a 100%. Operações paralelas podem superestimar o tempo ativo; não equivale ao contador de tempo ocioso do Windows.")
        case .memory: return L("Apps, cache e disponível são estimativas a partir das páginas do kernel. Swap é medido diretamente. Committed e pools do Windows não têm equivalência direta no macOS.")
        case .cpu: return showKernelTimes ? L("Linha branca tracejada: tempo do kernel · Clique direito para alterar o gráfico") : L("Clique direito no gráfico para exibir processadores lógicos ou tempos do kernel")
        default: return L("Amostragem a cada segundo · Histórico de 60 segundos")
        }
    }
}

struct HistoryGraph: View {
    let values: [Double]
    let color: Color
    let maximum: Double
    let grid: Bool
    var filled = true
    var dashed = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Canvas { context, size in
            if grid {
                var lines = Path()
                for column in 0...10 { let x = size.width * Double(column) / 10; lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height)) }
                for row in 0...5 { let y = size.height * Double(row) / 5; lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y)) }
                context.stroke(lines, with: .color(.secondary.opacity(0.12)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            }
            guard values.count > 1 else { return }
            var segment: [CGPoint] = []
            func drawSegment() {
                guard let first = segment.first, let last = segment.last else { return }
                var line = Path()
                line.move(to: first)
                for point in segment.dropFirst() { line.addLine(to: point) }
                if filled {
                    var fill = line
                    fill.addLine(to: CGPoint(x: last.x, y: size.height))
                    fill.addLine(to: CGPoint(x: first.x, y: size.height))
                    fill.closeSubpath()
                    context.fill(fill, with: .linearGradient(Gradient(colors: [color.opacity(colorScheme == .dark ? 0.42 : 0.28), color.opacity(0.025)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                }
                context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: grid ? 1.8 : 1.2, dash: dashed ? [4, 3] : []))
            }
            for (index, value) in values.enumerated() {
                guard value.isFinite else { drawSegment(); segment.removeAll(keepingCapacity: true); continue }
                segment.append(CGPoint(x: size.width * Double(index) / Double(values.count - 1), y: size.height * (1 - min(1, max(0, value / max(1, maximum))))))
            }
            drawSegment()
        }.accessibilityLabel(L("Gráfico de utilização dos últimos 60 segundos"))
    }
}
