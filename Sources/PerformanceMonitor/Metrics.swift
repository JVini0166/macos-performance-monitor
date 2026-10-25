import Foundation
import Darwin
import Combine

enum Resource: String, CaseIterable, Identifiable {
    case cpu = "CPU", memory = "Memória", disk = "Disco", network = "Rede", gpu = "GPU"
    var id: Self { self }
}

@MainActor final class Metrics: ObservableObject {
    @Published var history: [Resource: [Double]] = Dictionary(uniqueKeysWithValues: Resource.allCases.map { ($0, Array(repeating: 0, count: 60)) })
    @Published var cpu = 0.0
    @Published var gpus: [GPUReading] = []
    @Published var selectedGPUID = ""
    @Published var gpuEngineHistory: [String: [Double]] = [:]
    @Published var gpuMemoryHistory: [String: [Double]] = [:]
    @Published var cpuTemperature: TemperatureReading?
    @Published var gpuTemperature: TemperatureReading?
    private let gpuReader = GPUReader()
    private lazy var temperatureReader = TemperatureReader(processor: processor)
    var selectedGPU: GPUReading? { gpus.first { $0.id == selectedGPUID } }
    func gpuHistory(_ engine: GPUEngine) -> [Double] {
        gpuEngineHistory[selectedGPUID + engine.rawValue] ?? Array(repeating: .nan, count: 60)
    }

    @Published var memoryUsed = 0.0
    @Published var memoryWired = 0.0
    @Published var memoryCompressed = 0.0
    @Published var memoryApps = 0.0
    @Published var memoryCached = 0.0
    @Published var memoryFree = 0.0
    @Published var swapUsed = 0.0
    @Published var swapTotal = 0.0
    @Published var swapIn = 0.0
    @Published var swapOut = 0.0
    @Published var disks: [PhysicalDisk] = []
    @Published var selectedDiskID = ""
    @Published var diskRates: [String: DiskRates] = [:]
    @Published var diskHistory: [String: [Double]] = [:]
    @Published var diskReadHistory: [String: [Double]] = [:]
    @Published var diskWriteHistory: [String: [Double]] = [:]
    @Published var coreHistory: [[Double]] = []
    @Published var coreUsage: [Double] = []
    @Published var coreKernelHistory: [[Double]] = []
    @Published var kernelHistory = Array(repeating: 0.0, count: 60)
    private var previousDisks: [String: DiskCounters] = [:]
    private var previousCores: [[UInt64]] = []
    private var previousSwap: (UInt64, UInt64)?
    var selectedDisk: PhysicalDisk? { disks.first { $0.id == selectedDiskID } }
    var selectedDiskRates: DiskRates? { diskRates[selectedDiskID] }
    var memoryAvailable: Double { max(0, memoryTotal - memoryUsed) }
    @Published var received = 0.0
    @Published var sent = 0.0
    @Published var paused = false
    let memoryTotal = Double(ProcessInfo.processInfo.physicalMemory)
    let processor = Metrics.sysString("machdep.cpu.brand_string")
    let cores = Metrics.sysInt("hw.physicalcpu")
    let logical = ProcessInfo.processInfo.processorCount
    private var previousCPU: [UInt64]?
    private var previousNetwork: (UInt64, UInt64)?
    private var previousTime = ProcessInfo.processInfo.systemUptime
    private var timer: Timer?

    init() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    static func sysString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return "Apple Silicon" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return "Mac" }
        return String(cString: value)
    }
    static func sysInt(_ name: String) -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return Int(value)
    }
    func sample() {
        guard !paused else {
            previousTime = ProcessInfo.processInfo.systemUptime
            previousCPU = nil
            previousCores = []
            previousDisks = [:]
            previousNetwork = nil
            previousSwap = nil
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0.001, now - previousTime)
        sampleCores()
        cpuTemperature = temperatureReader.sampleCPU()
        gpuTemperature = temperatureReader.sampleGPU()
        gpus = gpuReader.sample()
        if !gpus.contains(where: { $0.id == selectedGPUID }) { selectedGPUID = gpus.first?.id ?? "" }
        for gpu in gpus {
            for engine in GPUEngine.allCases {
                appendGPU(gpu.engines[engine], to: &gpuEngineHistory, key: gpu.id + engine.rawValue)
            }
            appendGPU(gpu.memoryInUse, to: &gpuMemoryHistory, key: gpu.id)
        }
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        if result == KERN_SUCCESS {
            let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3].map(UInt64.init)
            if let old = previousCPU {
                let delta = zip(ticks, old).map { $0 &- $1 }
                let total = delta.reduce(0, +)
                cpu = total > 0 ? Double(total - delta[2]) / Double(total) * 100 : 0
            }
            previousCPU = ticks
        }
        var vm = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount) }
        }
        if vmResult == KERN_SUCCESS {
            let page = Double(vm_kernel_page_size)
            memoryWired = Double(vm.wire_count) * page
            memoryCompressed = Double(vm.compressor_page_count) * page
            memoryApps = max(0, (Double(vm.active_count) + Double(vm.inactive_count) - Double(vm.external_page_count) - Double(vm.purgeable_count)) * page)
            memoryUsed = min(memoryTotal, memoryApps + memoryWired + memoryCompressed)
            memoryCached = min(memoryAvailable, (Double(vm.external_page_count) + Double(vm.purgeable_count)) * page)
            memoryFree = Double(vm.free_count) * page
            if let old = previousSwap {
                swapIn = Double(vm.swapins >= old.0 ? vm.swapins - old.0 : 0) * page / elapsed
                swapOut = Double(vm.swapouts >= old.1 ? vm.swapouts - old.1 : 0) * page / elapsed
            }
            previousSwap = (vm.swapins, vm.swapouts)
        }
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            swapUsed = Double(swap.xsu_used)
            swapTotal = Double(swap.xsu_total)
        }
        disks = DiskReader.sample()
        if !disks.contains(where: { $0.id == selectedDiskID }) { selectedDiskID = disks.first?.id ?? "" }
        diskRates = [:]
        for disk in disks {
            if let old = previousDisks[disk.id], let rate = disk.counters.rates(since: old, elapsed: elapsed) {
                diskRates[disk.id] = rate
                append(rate.activeEstimate, to: &diskHistory, key: disk.id)
                append(rate.read, to: &diskReadHistory, key: disk.id)
                append(rate.write, to: &diskWriteHistory, key: disk.id)
            }
        }
        previousDisks = Dictionary(uniqueKeysWithValues: disks.map { ($0.id, $0.counters) })
        var addresses: UnsafeMutablePointer<ifaddrs>?
        var incoming: UInt64 = 0
        var outgoing: UInt64 = 0
        if getifaddrs(&addresses) == 0 {
            var cursor = addresses
            while let entry = cursor {
                let item = entry.pointee
                if item.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), (item.ifa_flags & UInt32(IFF_LOOPBACK)) == 0,
                   let data = item.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    incoming += UInt64(data.pointee.ifi_ibytes)
                    outgoing += UInt64(data.pointee.ifi_obytes)
                }
                cursor = item.ifa_next
            }
            freeifaddrs(addresses)
        }
        if let previous = previousNetwork {
            received = incoming >= previous.0 ? Double(incoming - previous.0) / elapsed : 0
            sent = outgoing >= previous.1 ? Double(outgoing - previous.1) / elapsed : 0
        }
        previousNetwork = (incoming, outgoing)
        previousTime = now
        guard !paused else { return }
        for resource in Resource.allCases {
            let value: Double
            switch resource {
            case .cpu: value = cpu
            case .memory: value = memoryUsed / memoryTotal * 100
            case .disk: value = selectedDiskRates?.activeEstimate ?? 0
            case .network: value = received + sent
            case .gpu: value = selectedGPU?.utilization ?? .nan
            }
            history[resource, default: []].append(value)
            history[resource]?.removeFirst()
        }
    }
    private func appendGPU(_ value: Double?, to histories: inout [String: [Double]], key: String) {
        var values = histories[key] ?? Array(repeating: .nan, count: 60)
        values.append(value ?? .nan)
        histories[key] = Array(values.suffix(60))
    }
    private func append(_ value: Double, to histories: inout [String: [Double]], key: String) {
        var values = histories[key] ?? Array(repeating: 0, count: 60)
        values.append(value)
        histories[key] = Array(values.suffix(60))
    }

    private func sampleCores() {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)) }
        let current = (0..<Int(count)).map { core in
            (0..<Int(CPU_STATE_MAX)).map { state in UInt64(UInt32(bitPattern: info[core * Int(CPU_STATE_MAX) + state])) }
        }
        if coreHistory.count != current.count {
            coreHistory = Array(repeating: Array(repeating: 0, count: 60), count: current.count)
            coreKernelHistory = coreHistory
        }
        coreUsage = Array(repeating: 0, count: current.count)
        if previousCores.count == current.count {
            var kernelTotal = 0.0
            for index in current.indices {
                let delta = zip(current[index], previousCores[index]).map { ($0 &- $1) & 0xffff_ffff }
                let total = delta.reduce(0, +)
                let usage = total > 0 ? Double(total - delta[Int(CPU_STATE_IDLE)]) / Double(total) * 100 : 0
                let kernel = total > 0 ? Double(delta[Int(CPU_STATE_SYSTEM)]) / Double(total) * 100 : 0
                kernelTotal += kernel
                coreKernelHistory[index].append(kernel)
                coreKernelHistory[index].removeFirst()
                coreUsage[index] = usage
                coreHistory[index].append(usage)
                coreHistory[index].removeFirst()
            }
            kernelHistory.append(kernelTotal / Double(max(1, current.count)))
            kernelHistory.removeFirst()
        }
        previousCores = current
    }

    func subtitle(_ resource: Resource) -> String {
        switch resource {
        case .cpu: return String(format: "%.0f%%", cpu)
        case .memory: return "\(Self.bytes(memoryUsed)) / \(Self.bytes(memoryTotal))"
        case .disk: return selectedDiskRates.map { String(format: "%.0f%% de atividade", $0.activeEstimate) } ?? "Aguardando I/O"
        case .gpu: return selectedGPU?.utilization.map { String(format: "%.0f%%", $0) } ?? "Indisponível"
        case .network: return "↑ \(Self.bytes(sent))/s  ↓ \(Self.bytes(received))/s"
        }
    }
    static func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }
    var uptime: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        return String(format: "%d:%02d:%02d:%02d", seconds / 86400, seconds / 3600 % 24, seconds / 60 % 60, seconds % 60)
    }
}
