import Foundation
import Metal
import IOKit

enum GPUEngine: String, CaseIterable, Identifiable {
    case overall = "Utilização geral"
    case renderer = "Renderização"
    case tiler = "Tiler"
    var id: String { rawValue }
    var counter: String {
        switch self {
        case .overall: return "Device Utilization %"
        case .renderer: return "Renderer Utilization %"
        case .tiler: return "Tiler Utilization %"
        }
    }
}

struct GPUReading: Identifiable {
    let id: String
    let name: String
    let unified: Bool
    let recommendedWorkingSet: Double
    let engines: [GPUEngine: Double]
    let memoryInUse: Double?
    let memoryAllocated: Double?
    let driver: String?
    var utilization: Double? { engines[.overall] }

    static func percentage(_ value: NSNumber?) -> Double? {
        guard let number = value?.doubleValue, number.isFinite, (0...100).contains(number) else { return nil }
        return number
    }
    static func memory(_ value: NSNumber?) -> Double? {
        guard let number = value?.doubleValue, number.isFinite, number >= 0 else { return nil }
        return number
    }
}

final class GPUReader {
    private let devices = MTLCopyAllDevices()
    func sample() -> [GPUReading] {
        devices.map { device in
            // Metal's registry ID binds the driver counters to the correct GPU.
            let entry = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(device.registryID))
            defer { if entry != 0 { IOObjectRelease(entry) } }
            let stats = entry != 0 ? DiskReader.property(entry, "PerformanceStatistics") as? [String: NSNumber] ?? [:] : [:]
            let engines = Dictionary(uniqueKeysWithValues: GPUEngine.allCases.compactMap { engine in
                GPUReading.percentage(stats[engine.counter]).map { (engine, $0) }
            })
            return GPUReading(id: String(device.registryID), name: device.name,
                              unified: device.hasUnifiedMemory,
                              recommendedWorkingSet: Double(device.recommendedMaxWorkingSetSize),
                              engines: engines,
                              memoryInUse: GPUReading.memory(stats["In use system memory"]),
                              memoryAllocated: GPUReading.memory(stats["Alloc system memory"]),
                              driver: entry != 0 ? DiskReader.property(entry, "CFBundleIdentifier") as? String : nil)
        }
    }
}
