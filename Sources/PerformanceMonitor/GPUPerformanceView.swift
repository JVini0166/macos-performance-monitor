import SwiftUI

struct GPUPerformanceView: View {
    @ObservedObject var metrics: Metrics
    private let color = Color(red: 0.70, green: 0.54, blue: 0.85)
    private var gpu: GPUReading? { metrics.selectedGPU }
    private var memoryMaximum: Double {
        // Physical shared RAM is a scale, not a VRAM allocation or a GPU reservation.
        max(metrics.memoryTotal, (metrics.gpuMemoryHistory[metrics.selectedGPUID] ?? []).filter(\.isFinite).max() ?? 0)
    }
    private var temperature: TemperatureReading? {
        guard let gpu, gpu.unified, metrics.processor.contains(gpu.name) else { return nil }
        return metrics.gpuTemperature
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("GPU").font(.system(size: 35))
                    Spacer()
                    Text(gpu?.name ?? "GPU indisponível").font(.system(size: 15))
                }.padding(.top, 5)
                if metrics.gpus.count > 1 {
                    Picker("GPU", selection: $metrics.selectedGPUID) {
                        ForEach(metrics.gpus) { Text($0.name).tag($0.id) }
                    }.pickerStyle(.menu)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(GPUEngine.allCases) { engine in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(engine.rawValue)
                                Spacer()
                                Text(gpu?.engines[engine].map { String(format: "%.0f%%", $0) } ?? "—")
                            }.font(.system(size: 11)).foregroundStyle(.secondary)
                            HistoryGraph(values: metrics.gpuHistory(engine), color: color, maximum: 100, grid: true)
                                .overlay { if gpu?.engines[engine] == nil { unavailable("Contador indisponível") } }
                                .frame(height: 100)
                        }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Vídeo · Encode / Decode").font(.system(size: 11)).foregroundStyle(.secondary)
                        Rectangle().fill(color.opacity(0.035)).overlay { unavailable("Não exposto pelo driver") }.frame(height: 100)
                    }
                }
                HStack { Text("60 segundos"); Spacer(); Text("0 · Escala de utilização: 100%") }.font(.system(size: 10)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(gpu?.unified == true ? "Memória compartilhada da GPU em uso" : "Memória de sistema usada pela GPU")
                        Spacer()
                        Text(Metrics.bytes(memoryMaximum))
                    }.font(.system(size: 11)).foregroundStyle(.secondary)
                    HistoryGraph(values: metrics.gpuMemoryHistory[metrics.selectedGPUID] ?? [], color: color, maximum: memoryMaximum, grid: true)
                        .frame(height: 85)
                        .overlay { if gpu?.memoryInUse == nil { unavailable("Contador de memória indisponível") } }
                    HStack { Text("60 segundos"); Spacer(); Text("0") }.font(.system(size: 10)).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 18) {
                    metric("Utilização", gpu?.utilization.map { String(format: "%.0f%%", $0) } ?? "Indisponível")
                    metric("Memória em uso (driver)", gpu?.memoryInUse.map(Metrics.bytes) ?? "Indisponível")
                    metric("Memória alocada (driver)", gpu?.memoryAllocated.map(Metrics.bytes) ?? "Indisponível")
                    metric("Temperatura (máxima)", TemperatureReading.formatted(temperature))
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    detail("Modelo de memória:", gpu.map { $0.unified ? "Unificada · Compartilhada com a CPU" : "GPU com memória separada" } ?? "—")
                    detail("Memória dedicada:", gpu?.unified == true ? "Não se aplica à memória unificada" : "Contador indisponível")
                    detail("RAM física do Mac:", Metrics.bytes(metrics.memoryTotal))
                    detail("Working set recomendado:", gpu.map { Metrics.bytes($0.recommendedWorkingSet) } ?? "—")
                    detail("Driver:", gpu?.driver ?? "Indisponível")
                    detail("Sensores térmicos:", temperature.map { "AppleSMC · " + $0.sensors.joined(separator: ", ") } ?? "Indisponíveis para esta GPU")
                }
                Text("Amostragem de 1 segundo · Contadores globais do driver IOKit. Memória em uso e alocada são contadores distintos e não devem ser somados. O working set recomendado pelo Metal não é VRAM reservada nem um limite rígido. Sensores e contadores variam por hardware e versão do macOS.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(.bottom, 20)
        }
    }
    func unavailable(_ message: String) -> some View {
        Text(message).font(.system(size: 11)).foregroundStyle(.secondary).padding(8).background(Color(white: 0.085).opacity(0.9))
    }
    func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 23)).monospacedDigit().textSelection(.enabled)
        }
    }
    func detail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary).frame(width: 180, alignment: .leading)
            Text(value).textSelection(.enabled)
        }.font(.system(size: 12))
    }
}
