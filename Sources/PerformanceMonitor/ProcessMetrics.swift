import Foundation
import AppKit
import Combine
import Darwin

struct ProcessCounters: Sendable {
    let cpuNanoseconds: Double
    let readBytes: UInt64
    let writeBytes: UInt64
    let sampledAt: Double
    func rates(since old: Self) -> (cpu: Double, read: Double, write: Double)? {
        let elapsed = sampledAt - old.sampledAt
        guard elapsed > 0, cpuNanoseconds >= old.cpuNanoseconds, readBytes >= old.readBytes, writeBytes >= old.writeBytes else { return nil }
        return (Double(cpuNanoseconds - old.cpuNanoseconds) / elapsed / 10_000_000,
                Double(readBytes - old.readBytes) / elapsed, Double(writeBytes - old.writeBytes) / elapsed)
    }
}

struct ProcessSample: Identifiable, Sendable {
    let id: String
    let pid: Int32
    let parentPID: UInt32
    let uid: uid_t
    var name: String
    let state: String
    let memory: Double?
    let threads: Int?
    let counters: ProcessCounters?
    var cpu: Double?
    var read: Double?
    var write: Double?
    var isApp = false
    var user = ""
    var cpuSort: Double { cpu ?? -1 }
    var memorySort: Double { memory ?? -1 }
    var readSort: Double { read ?? -1 }
    var writeSort: Double { write ?? -1 }
    var threadSort: Int { threads ?? -1 }
}

enum ProcessReader {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
    static func nanoseconds(ticks: UInt64, numerator: UInt32, denominator: UInt32) -> Double {
        Double(ticks) * Double(numerator) / Double(max(1, denominator))
    }

    static func read() -> [ProcessSample] {
        let capacity = max(256, Int(proc_listallpids(nil, 0)) * 2 + 128)
        var pids = [Int32](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard count > 0 else { return [] }
        return pids.prefix(min(Int(count), capacity)).compactMap { sample(pid: $0) }
    }
    static func sample(pid: Int32) -> ProcessSample? {
        guard pid > 0 else { return nil }
        var bsd = proc_bsdinfo()
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) == MemoryLayout<proc_bsdinfo>.size else { return nil }
        var buffer = [CChar](repeating: 0, count: 1024)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        let name = length > 0 ? String(cString: buffer) : L("Processo \(pid)")
        var usage = rusage_info_v2()
        let success = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) == 0 }
        }
        var task = proc_taskinfo()
        let hasTask = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size)) == MemoryLayout<proc_taskinfo>.size
        let counters = success ? ProcessCounters(cpuNanoseconds: nanoseconds(ticks: usage.ri_user_time + usage.ri_system_time, numerator: timebase.numer, denominator: timebase.denom),
                                                readBytes: usage.ri_diskio_bytesread, writeBytes: usage.ri_diskio_byteswritten,
                                                sampledAt: ProcessInfo.processInfo.systemUptime) : nil
        let state: String
        switch bsd.pbi_status {
        case 1: state = "Iniciando"
        case 2: state = "Executando"
        case 3: state = "Em espera"
        case 4: state = "Suspenso"
        case 5: state = "Encerrado"
        default: state = "Desconhecido"
        }
        return ProcessSample(id: "\(pid):\(bsd.pbi_start_tvsec):\(bsd.pbi_start_tvusec)", pid: pid,
                             parentPID: bsd.pbi_ppid, uid: bsd.pbi_uid, name: name, state: state,
                             memory: success ? Double(usage.ri_phys_footprint) : hasTask ? Double(task.pti_resident_size) : nil,
                             threads: hasTask ? Int(task.pti_threadnum) : nil, counters: counters)
    }
}

@MainActor final class ProcessMetrics: ObservableObject {
    @Published var processes: [ProcessSample] = []
    @Published var loading = true
    @Published var error: String?
    var icons: [Int32: NSImage] = [:]
    private var previous: [String: ProcessCounters] = [:]
    private var users: [uid_t: String] = [:]

    func resetBaseline() { previous = [:] }
    func refresh() async {
        let samples = await Task.detached(priority: .utility) { ProcessReader.read() }.value
        guard !Task.isCancelled else { return }
        let apps = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) })
        processes = samples.map { sample in
            var item = sample
            if let app = apps[item.pid] {
                item.isApp = app.activationPolicy == .regular
                item.name = app.localizedName ?? item.name
                if icons[item.pid] == nil { icons[item.pid] = app.icon }
            }
            if users[item.uid] == nil {
                users[item.uid] = getpwuid(item.uid).map { String(cString: $0.pointee.pw_name) } ?? String(item.uid)
            }
            item.user = users[item.uid] ?? String(item.uid)
            if let current = item.counters, let old = previous[item.id], let rates = current.rates(since: old) {
                item.cpu = rates.cpu
                item.read = rates.read
                item.write = rates.write
            }
            return item
        }
        let livePIDs = Set(samples.map(\.pid))
        icons = icons.filter { livePIDs.contains($0.key) }
        previous = Dictionary(uniqueKeysWithValues: samples.compactMap { sample in sample.counters.map { (sample.id, $0) } })
        loading = false
    }

    func canTerminate(_ item: ProcessSample) -> Bool {
        item.pid > 1 && item.pid != getpid() && item.uid == getuid() && item.counters != nil
    }
    func terminate(_ item: ProcessSample, force: Bool) {
        guard canTerminate(item), let fresh = ProcessReader.sample(pid: item.pid), fresh.id == item.id, fresh.uid == getuid() else {
            error = L("O processo já encerrou ou não pode ser finalizado por este usuário.")
            return
        }
        if kill(item.pid, force ? SIGKILL : SIGTERM) != 0 {
            error = L("Não foi possível encerrar \(item.name): \(String(cString: strerror(errno)))")
        }
    }
}
