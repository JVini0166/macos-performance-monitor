import SwiftUI

private enum ProcessScope: String, CaseIterable, Identifiable {
    case all = "Todos", apps = "Aplicativos", background = "Segundo plano", mine = "Meu usuário"
    var id: Self { self }
}

struct ProcessesView: View {
    @ObservedObject var metrics: Metrics
    @ObservedObject var store: ProcessMetrics
    @State private var search = ""
    @State private var scope: ProcessScope = .all
    @State private var selection: ProcessSample.ID?
    @State private var sortOrder = [KeyPathComparator(\ProcessSample.cpuSort, order: .reverse)]
    @State private var inspected: ProcessSample?
    @State private var pendingTermination: ProcessSample?
    @State private var confirmTermination = false
    private var selected: ProcessSample? { store.processes.first { $0.id == selection } }
    private var visible: [ProcessSample] {
        store.processes.filter { item in
            let matchesScope: Bool
            switch scope {
            case .all: matchesScope = true
            case .apps: matchesScope = item.isApp
            case .background: matchesScope = !item.isApp
            case .mine: matchesScope = item.uid == getuid()
            }
            return matchesScope && (search.isEmpty || item.name.localizedStandardContains(search) || String(item.pid).contains(search) || item.user.localizedStandardContains(search))
        }.sorted(using: sortOrder)
    }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L("Processos")).font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text(L("\(store.processes.count) processos · \(store.processes.filter(\.isApp).count) aplicativos"))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker(L("Filtrar processos"), selection: $scope) {
                        ForEach(ProcessScope.allCases) { Text(L10n.text($0.rawValue)).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 430)
                }
                HStack(spacing: 14) {
                    summary("CPU", value: metrics.subtitle(.cpu), symbol: "cpu", color: Resource.cpu.color)
                    summary(L("Memória"), value: L10n.number("%.0f%%", metrics.memoryUsed / metrics.memoryTotal * 100), symbol: "memorychip", color: Resource.memory.color)
                    summary(L("Disco · Leitura + escrita"), value: Metrics.bytes(metrics.diskRates.values.reduce(0) { $0 + $1.read + $1.write }) + "/s", symbol: "internaldrive", color: Resource.disk.color)
                    summary("GPU", value: metrics.subtitle(.gpu), symbol: "square.3.layers.3d", color: Resource.gpu.color)
                }
                processTable
                    .overlay {
                        if store.loading { ProgressView(L("Carregando processos…")) }
                        else if visible.isEmpty { ContentUnavailableView.search(text: search) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.06), lineWidth: 0.5) }
                HStack {
                    Text(L("\(visible.count) exibidos"))
                    Spacer()
                    Text(L("CPU: 100% por processador lógico · Atualização: 2 s · — indica leitura indisponível"))
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(24)
            .background {
                ZStack(alignment: .topTrailing) {
                    Color(nsColor: .windowBackgroundColor)
                    RadialGradient(colors: [Color.accentColor.opacity(0.06), .clear], center: .topTrailing, startRadius: 0, endRadius: 650)
                }.ignoresSafeArea()
            }
            .navigationTitle(L("Processos"))
            .navigationSubtitle(L("Monitor de Performance"))
            .searchable(text: $search, placement: .toolbar, prompt: L("Nome, PID ou usuário"))
            .toolbar {
                ToolbarItem(placement: .status) { LiveStatus(paused: metrics.paused) }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { if let selected { inspected = selected } } label: { Label(L("Informações"), systemImage: "info.circle") }.disabled(selected == nil)
                    Button {
                        pendingTermination = selected
                        confirmTermination = true
                    } label: { Label(L("Finalizar processo"), systemImage: "xmark.octagon") }
                    .disabled(selected.map { !store.canTerminate($0) } ?? true)
                    Button { metrics.paused.toggle() } label: { Label(metrics.paused ? L("Retomar") : L("Pausar"), systemImage: metrics.paused ? "play.fill" : "pause.fill") }
                        .help(L("Pausar ou retomar (⌘P)"))
                }
            }
            .confirmationDialog(L("Finalizar \(pendingTermination?.name ?? L("processo"))?"), isPresented: $confirmTermination, titleVisibility: .visible) {
                if let item = pendingTermination {
                    Button(L("Encerrar"), role: .destructive) { store.terminate(item, force: false) }
                    Button(L("Forçar encerramento"), role: .destructive) { store.terminate(item, force: true) }
                }
                Button(L("Cancelar"), role: .cancel) { pendingTermination = nil }
            } message: { Text(L("O processo será encerrado. Alterações não salvas podem ser perdidas.")) }
            .alert(L("Não foi possível finalizar"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .sheet(item: $inspected) { item in
                ProcessInspector(sample: item)
            }
        }
    }
    private var processTable: some View {
        Table(visible, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(L("Nome"), value: \.name) { item in
                HStack(spacing: 9) {
                    if let image = store.icons[item.pid] { Image(nsImage: image).resizable().frame(width: 22, height: 22) }
                    else { Image(systemName: "terminal").foregroundStyle(.secondary).frame(width: 22) }
                    Text(item.name).font(.system(size: 12, weight: item.isApp ? .medium : .regular)).lineLimit(1)
                }.padding(.vertical, 4)
            }.width(min: 180, ideal: 250)
            TableColumn(L("Estado"), value: \.state) { item in
                Text(L10n.text(item.state)).font(.system(size: 11)).foregroundStyle(.secondary)
            }.width(85)
            TableColumn("CPU", value: \.cpuSort) { item in
                heat(item.cpu.map { L10n.number("%.1f%%", $0) }, intensity: (item.cpu ?? 0) / 100, color: Resource.cpu.color)
            }.width(75)
            TableColumn(L("Memória"), value: \.memorySort) { item in
                heat(item.memory.map(Metrics.bytes), intensity: (item.memory ?? 0) / metrics.memoryTotal, color: Resource.memory.color)
            }.width(100)
            TableColumn(L("Leitura"), value: \.readSort) { item in
                heat(item.read.map { Metrics.bytes($0) + "/s" }, intensity: (item.read ?? 0) / 50_000_000, color: Resource.disk.color)
            }.width(100)
            TableColumn(L("Escrita"), value: \.writeSort) { item in
                heat(item.write.map { Metrics.bytes($0) + "/s" }, intensity: (item.write ?? 0) / 50_000_000, color: Resource.disk.color)
            }.width(100)
            TableColumn("Threads", value: \.threadSort) { item in Text(item.threads.map(String.init) ?? "—").monospacedDigit() }.width(65)
            TableColumn(L("Usuário"), value: \.user).width(min: 80, ideal: 100)
            TableColumn("PID", value: \.pid) { item in Text(String(item.pid)).monospacedDigit().foregroundStyle(.secondary) }.width(65)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu {
            if let selected {
                Button(L("Informações do processo")) { inspected = selected }
                Button(L("Finalizar processo…")) { pendingTermination = selected; confirmTermination = true }.disabled(!store.canTerminate(selected))
            }
        }
        .onChange(of: search) { _, _ in selection = nil }
        .onChange(of: scope) { _, _ in selection = nil }
    }
    private func heat(_ value: String?, intensity: Double, color: Color) -> some View {
        Text(value ?? "—").font(.system(size: 11)).monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 6).padding(.vertical, 7)
            .background(color.opacity(value == nil ? 0 : 0.03 + min(1, max(0, intensity)) * 0.32), in: RoundedRectangle(cornerRadius: 5))
    }
    private func summary(_ title: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text(title)).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 23, weight: .medium, design: .rounded)).monospacedDigit()
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity).monitorSurface()
    }
}

private struct ProcessInspector: View {
    let sample: ProcessSample
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(sample.name, systemImage: "app.dashed").font(.title2.bold())
            LabeledContent("PID", value: String(sample.pid))
            LabeledContent(L("Processo pai"), value: String(sample.parentPID))
            LabeledContent(L("Usuário"), value: sample.user)
            LabeledContent(L("Estado"), value: L10n.text(sample.state))
            LabeledContent(L("Tipo"), value: sample.isApp ? L("Aplicativo") : L("Segundo plano"))
            LabeledContent("CPU", value: sample.cpu.map { L10n.number("%.1f%%", $0) } ?? L("Indisponível"))
            LabeledContent(L("Memória"), value: sample.memory.map(Metrics.bytes) ?? L("Indisponível"))
            LabeledContent("Threads", value: sample.threads.map(String.init) ?? L("Indisponível"))
            Text(L("Retrato da última amostra. GPU e rede por processo não são expostas nesta versão. Processos protegidos pelo sistema podem restringir leituras.")).font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button(L("Concluído")) { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 430).textSelection(.enabled)
    }
}
