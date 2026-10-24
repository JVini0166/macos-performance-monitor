import SwiftUI
import AppKit

@main struct PerformanceMonitorApp: App {
    @StateObject private var metrics = Metrics()
    var body: some Scene {
        WindowGroup("Performance Monitor") {
            PerformanceView(metrics: metrics)
                .preferredColorScheme(.dark)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1260, height: 790)
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(after: .newItem) {
            Button(metrics.paused ? "Retomar gráficos" : "Pausar gráficos") { metrics.paused.toggle() }.keyboardShortcut("p", modifiers: [.command])
        } }
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
    @State private var selection: Resource = .cpu
    @State private var sidebarVisible = true
    @AppStorage("logicalProcessors") private var logicalProcessors = false
    @AppStorage("showKernelTimes") private var showKernelTimes = false
    private let background = Color(white: 0.085)
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }.buttonStyle(.plain)
                Image(systemName: "waveform.path.ecg.rectangle").foregroundStyle(.cyan)
                Text("Performance Monitor").font(.system(size: 14, weight: .medium))
                Spacer()
                HStack(spacing: 6) { Circle().fill(metrics.paused ? .orange : .green).frame(width: 6, height: 6); Text(metrics.paused ? "Gráficos pausados" : "Em tempo real").foregroundStyle(.secondary) }.font(.system(size: 11))
            }.padding(.horizontal, 24).frame(height: 58).background(Color(red: 0.10, green: 0.13, blue: 0.15))
            HStack(spacing: 0) {
                if sidebarVisible {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 14) { Image(systemName: "waveform.path.ecg"); Text("Performance") }
                            .font(.system(size: 15, weight: .medium)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06)).overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 3).fill(.cyan).frame(width: 3, height: 24) }.clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                        Label("macOS · \(ProcessInfo.processInfo.operatingSystemVersionString)", systemImage: "desktopcomputer")
                            .font(.system(size: 11)).foregroundStyle(.secondary).padding(12)
                    }.padding(8).frame(width: 200).background(Color(red: 0.105, green: 0.13, blue: 0.16))
                }
                VStack(spacing: 0) {
                    HStack {
                        Text("Performance").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Button { metrics.paused.toggle() } label: { Label(metrics.paused ? "Retomar" : "Pausar", systemImage: metrics.paused ? "play" : "pause") }.buttonStyle(.plain)
                            .help("Pausar ou retomar os gráficos (⌘P)")
                    }.padding(.horizontal, 24).frame(height: 59).background(Color(white: 0.13))
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    HStack(alignment: .top, spacing: 26) {
                        VStack(spacing: 8) {
                            ForEach(Resource.allCases) { resource in
                                Button { selection = resource } label: {
                                    HStack(spacing: 12) {
                                        HistoryGraph(values: resource == .disk ? metrics.diskHistory[metrics.selectedDiskID] ?? [] : resource == .gpu ? metrics.gpuHistory(.overall) : metrics.history[resource] ?? [], color: resource.color, maximum: maximum(resource), grid: false)
                                            .frame(width: 76, height: 51).background(Color.white.opacity(0.035)).overlay(Rectangle().stroke(resource.color.opacity(0.35), lineWidth: 0.5))
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(resource.rawValue).font(.system(size: 18))
                                            Text(metrics.subtitle(resource)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }.padding(12).frame(height: 87).background(selection == resource ? Color.white.opacity(0.075) : .clear).clipShape(RoundedRectangle(cornerRadius: 4))
                                }.buttonStyle(.plain)
                            }
                            Spacer()
                        }.frame(width: 228)
                        Group {
                            if selection == .gpu { GPUPerformanceView(metrics: metrics) }
                            else { detail }
                        }.padding(.trailing, 24)
                    }.padding(.top, 18).padding(.leading, 10)
                }.background(background)
            }
        }.foregroundStyle(Color(white: 0.94))
    }
    func maximum(_ resource: Resource) -> Double {
        resource == .network ? max(1024, (metrics.history[.network] ?? []).max() ?? 0) * 1.15 : 100
    }
    var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(selection.rawValue).font(.system(size: 35, weight: .regular))
                    Spacer(minLength: 16)
                    Text(detailTitle).font(.system(size: 15)).lineLimit(2).multilineTextAlignment(.trailing)
                }.padding(.top, 5).padding(.bottom, 18)
                if selection == .disk, !metrics.disks.isEmpty {
                    Picker("Disco físico", selection: $metrics.selectedDiskID) {
                        ForEach(metrics.disks) { disk in Text("\(disk.id) · \(disk.name)").tag(disk.id) }
                    }.pickerStyle(.menu).frame(maxWidth: 380).padding(.bottom, 12)
                }
                HStack {
                    Text(graphLabel)
                    Spacer()
                    if selection == .cpu {
                        Menu {
                            cpuGraphOptions
                        } label: { Image(systemName: "square.grid.2x2") }
                        .menuStyle(.borderlessButton).fixedSize().help("Alterar gráfico da CPU; também disponível com clique direito")
                    }
                    Text(selection == .network ? "\(Metrics.bytes(maximum(selection)))/s" : selection == .memory ? Metrics.bytes(metrics.memoryTotal) : "100%")
                }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 5)
                Group {
                    if selection == .cpu && logicalProcessors {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: coreColumns), spacing: 10) {
                            ForEach(metrics.coreHistory.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack { Text("CPU \(index)"); Spacer(); Text(String(format: "%.0f%%", metrics.coreUsage[index])) }.font(.system(size: 10)).foregroundStyle(.secondary)
                                    ZStack {
                                        HistoryGraph(values: metrics.coreHistory[index], color: selection.color, maximum: 100, grid: true)
                                        if showKernelTimes {
                                            HistoryGraph(values: metrics.coreKernelHistory[index], color: .white.opacity(0.8), maximum: 100, grid: false, filled: false, dashed: true)
                                        }
                                    }
                                }.frame(height: coreHeight)
                            }
                        }
                    } else {
                        ZStack {
                            HistoryGraph(values: selection == .disk ? metrics.diskHistory[metrics.selectedDiskID] ?? [] : metrics.history[selection] ?? [], color: selection.color, maximum: maximum(selection), grid: true)
                            if selection == .cpu && showKernelTimes {
                                HistoryGraph(values: metrics.kernelHistory, color: .white.opacity(0.8), maximum: 100, grid: false, filled: false, dashed: true)
                            }
                        }.frame(height: selection == .disk ? 165 : selection == .memory ? 220 : 300)
                    }
                }.contextMenu {
                    if selection == .cpu {
                        Menu("Alterar gráfico para") { cpuGraphOptions }
                        Toggle("Mostrar tempos do kernel", isOn: $showKernelTimes)
                        Divider()
                        Button("Copiar resumo") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("CPU: \(metrics.processor)\nUtilização: \(metrics.subtitle(.cpu))\nNúcleos: \(metrics.cores)\nProcessadores lógicos: \(metrics.logical)", forType: .string)
                        }
                    }
                }
                HStack { Text("60 segundos"); Spacer(); Text("0") }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 6)
                if selection == .disk { diskTransferGraph.padding(.top, 16) }
                if selection == .memory { memoryComposition.padding(.top, 16) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), alignment: .leading)], alignment: .leading, spacing: 18) {
                    ForEach(statistics, id: \.0) { entry in statistic(entry.0, entry.1) }
                }.padding(.top, 22)
                Divider().padding(.vertical, 18)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(details, id: \.0) { entry in
                        HStack(alignment: .top) {
                            Text(entry.0).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                            Text(entry.1).textSelection(.enabled)
                        }.font(.system(size: 12))
                    }
                }
                Text(footnote).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 18).padding(.bottom, 20)
            }
        }
    }
    var coreColumns: Int { metrics.logical <= 4 ? 2 : metrics.logical <= 16 ? 4 : 8 }
    var coreHeight: CGFloat { metrics.logical <= 16 ? 85 : 65 }
    @ViewBuilder var cpuGraphOptions: some View {
        Button { logicalProcessors = false } label: { Label("Utilização geral", systemImage: logicalProcessors ? "circle" : "checkmark.circle.fill") }
        Button { logicalProcessors = true } label: { Label("Processadores lógicos", systemImage: logicalProcessors ? "checkmark.circle.fill" : "circle") }
    }
    var diskTransferMaximum: Double {
        max(1_048_576, max((metrics.diskReadHistory[metrics.selectedDiskID] ?? []).max() ?? 0, (metrics.diskWriteHistory[metrics.selectedDiskID] ?? []).max() ?? 0) * 1.15)
    }
    var diskTransferGraph: some View {
        VStack(spacing: 5) {
            HStack { Text("Taxa de transferência do disco"); Spacer(); Text("\(Metrics.bytes(diskTransferMaximum))/s") }.font(.system(size: 11)).foregroundStyle(.secondary)
            ZStack {
                HistoryGraph(values: metrics.diskReadHistory[metrics.selectedDiskID] ?? [], color: Resource.disk.color, maximum: diskTransferMaximum, grid: true, filled: false)
                HistoryGraph(values: metrics.diskWriteHistory[metrics.selectedDiskID] ?? [], color: Resource.disk.color.opacity(0.7), maximum: diskTransferMaximum, grid: false, filled: false, dashed: true)
            }.frame(height: 95)
            HStack { Text("60 segundos"); Spacer(); Text("— Leitura    ┄ Escrita") }.font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
    var memoryComposition: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Composição da memória").font(.system(size: 11)).foregroundStyle(.secondary)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    compositionSegment("Apps (estimativa)", metrics.memoryApps, 0.75, geometry.size.width)
                    compositionSegment("Wired", metrics.memoryWired, 1, geometry.size.width)
                    compositionSegment("Comprimida", metrics.memoryCompressed, 0.5, geometry.size.width)
                    compositionSegment("Disponível", metrics.memoryAvailable, 0.08, geometry.size.width)
                }
            }.frame(height: 32).overlay(Rectangle().stroke(Resource.memory.color, lineWidth: 1))
            Text("Apps · Wired · Comprimida · Disponível").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
    func compositionSegment(_ label: String, _ value: Double, _ opacity: Double, _ width: CGFloat) -> some View {
        Rectangle().fill(Resource.memory.color.opacity(opacity)).frame(width: width * value / metrics.memoryTotal)
            .help("\(label): \(Metrics.bytes(value))")
    }
    func statistic(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 23, weight: .regular)).monospacedDigit().textSelection(.enabled)
        }
    }
    var graphLabel: String {
        switch selection {
        case .cpu: return logicalProcessors ? "Utilização por processador lógico" : "% Utilização"
        case .memory: return "Uso da memória física"
        case .disk: return "% Tempo ativo (estimativa)"
        case .gpu: return "% Utilização"
        case .network: return "Taxa de transferência"
        }
    }
    var detailTitle: String {
        switch selection {
        case .cpu: return metrics.processor
        case .memory: return "\(Metrics.bytes(metrics.memoryTotal)) de memória física"
        case .disk: return metrics.selectedDisk?.name ?? "Disco indisponível"
        case .gpu: return metrics.selectedGPU?.name ?? "GPU indisponível"
        case .network: return "Interfaces de rede · Total agregado"
        }
    }
    var statistics: [(String, String)] {
        let bytes = Metrics.bytes
        switch selection {
        case .cpu: return [("Utilização", metrics.subtitle(.cpu)), ("Tempo de atividade", metrics.uptime), ("Temperatura (máxima)", TemperatureReading.formatted(metrics.cpuTemperature))]
        case .memory: return [
            ("Em uso (comprimida)", "\(bytes(metrics.memoryUsed)) (\(bytes(metrics.memoryCompressed)))"),
            ("Disponível (estimativa)", bytes(metrics.memoryAvailable)),
            ("Em cache (estimativa)", bytes(metrics.memoryCached)),
            ("Swap usado", bytes(metrics.swapUsed)),
            ("Swap alocado", bytes(metrics.swapTotal)),
            ("Wired (não paginável)", bytes(metrics.memoryWired))]
        case .disk:
            let rate = metrics.selectedDiskRates
            return [("Tempo ativo (estimativa)", rate.map { String(format: "%.1f%%", $0.activeEstimate) } ?? "—"),
                    ("Tempo médio de I/O", rate?.responseMS.map { String(format: "%.2f ms", $0) } ?? "—"),
                    ("Velocidade de leitura", rate.map { "\(bytes($0.read))/s" } ?? "—"),
                    ("Velocidade de escrita", rate.map { "\(bytes($0.write))/s" } ?? "—")]
        case .gpu: return []
        case .network: return [("Recebimento", "\(bytes(metrics.received))/s"), ("Envio", "\(bytes(metrics.sent))/s")]
        }
    }
    var details: [(String, String)] {
        let bytes = Metrics.bytes
        switch selection {
        case .cpu: return [("Núcleos:", "\(metrics.cores)"), ("Processadores lógicos:", "\(metrics.logical)"), ("Arquitetura:", Metrics.sysString("hw.machine")), ("Frequência atual:", "Não disponível"), ("Sensores térmicos:", metrics.cpuTemperature.map { "AppleSMC · " + $0.sensors.joined(separator: ", ") } ?? "Indisponíveis neste hardware")]
        case .memory: return [("Memória física:", bytes(metrics.memoryTotal)), ("Apps (estimativa):", bytes(metrics.memoryApps)),
                              ("Livre:", bytes(metrics.memoryFree)), ("Swap disponível:", bytes(max(0, metrics.swapTotal - metrics.swapUsed))),
                              ("Swap de entrada:", "\(bytes(metrics.swapIn))/s"), ("Swap de saída:", "\(bytes(metrics.swapOut))/s")]
        case .disk: return [("Disco físico:", metrics.selectedDisk?.id ?? "—"),
                            ("Capacidade:", metrics.selectedDisk.map { bytes($0.capacity) } ?? "—"),
                            ("Conexão:", metrics.selectedDisk?.connection ?? "—"),
                            ("Operações por segundo:", metrics.selectedDiskRates.map { String(format: "%.0f IOPS", $0.operations) } ?? "—")]
        case .gpu: return []
        case .network: return [("Escopo:", "Interfaces sem loopback"), ("Unidade:", "Bytes por segundo")]
        }
    }
    var footnote: String {
        switch selection {
        case .disk: return "Atividade estimada pela soma dos tempos de I/O ÷ intervalo, limitada a 100%. Operações paralelas podem superestimar o tempo ativo; não equivale ao contador de tempo ocioso do Windows."
        case .memory: return "Apps, cache e disponível são estimativas a partir das páginas do kernel. Swap é medido diretamente. Committed e pools do Windows não têm equivalência direta no macOS."
        case .cpu: return showKernelTimes ? "Linha branca tracejada: tempo do kernel · Clique direito para alterar o gráfico" : "Clique direito no gráfico para exibir processadores lógicos ou tempos do kernel"
        default: return "Amostragem a cada segundo · Histórico de 60 segundos"
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
    var body: some View {
        Canvas { context, size in
            if grid {
                var lines = Path()
                for column in 0...15 { let x = size.width * Double(column) / 15; lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height)) }
                for row in 0...10 { let y = size.height * Double(row) / 10; lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y)) }
                context.stroke(lines, with: .color(color.opacity(0.16)), lineWidth: 0.6)
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
                    context.fill(fill, with: .color(color.opacity(grid ? 0.56 : 0.46)))
                }
                context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: grid ? 1.4 : 1, dash: dashed ? [4, 3] : []))
            }
            for (index, value) in values.enumerated() {
                guard value.isFinite else { drawSegment(); segment.removeAll(keepingCapacity: true); continue }
                segment.append(CGPoint(x: size.width * Double(index) / Double(values.count - 1), y: size.height * (1 - min(1, max(0, value / max(1, maximum))))))
            }
            drawSegment()
        }.accessibilityLabel("Gráfico de utilização dos últimos 60 segundos")
    }
}
