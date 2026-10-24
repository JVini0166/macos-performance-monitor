import Foundation
import IOKit

struct DiskCounters {
    var readBytes: UInt64
    var writeBytes: UInt64
    var reads: UInt64
    var writes: UInt64
    var readTime: UInt64
    var writeTime: UInt64

    func rates(since old: Self, elapsed: Double) -> DiskRates? {
        guard elapsed > 0, readBytes >= old.readBytes, writeBytes >= old.writeBytes,
              reads >= old.reads, writes >= old.writes, readTime >= old.readTime, writeTime >= old.writeTime else { return nil }
        let operations = Double(reads - old.reads) + Double(writes - old.writes)
        let nanoseconds = Double(readTime - old.readTime) + Double(writeTime - old.writeTime)
        return DiskRates(read: Double(readBytes - old.readBytes) / elapsed,
                         write: Double(writeBytes - old.writeBytes) / elapsed,
                         operations: operations / elapsed,
                         responseMS: operations > 0 ? nanoseconds / operations / 1_000_000 : nil,
                         activeEstimate: min(100, nanoseconds / (elapsed * 1_000_000_000) * 100))
    }
}

struct DiskRates {
    var read: Double = 0
    var write: Double = 0
    var operations: Double = 0
    var responseMS: Double?
    var activeEstimate: Double = 0
}

struct PhysicalDisk: Identifiable {
    let id: String
    let name: String
    let capacity: Double
    let connection: String
    let counters: DiskCounters
}

enum DiskReader {
    static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    static func sample() -> [PhysicalDisk] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var disks: [PhysicalDisk] = []
        while true {
            let driver = IOIteratorNext(iterator)
            guard driver != 0 else { break }
            defer { IOObjectRelease(driver) }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(driver, kIOServicePlane, &parent) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(parent) }
            let protocolInfo = property(parent, "Protocol Characteristics") as? [String: Any] ?? [:]
            let connection = protocolInfo["Physical Interconnect"] as? String ?? "Desconhecida"
            // Disk images are IOBlockStorageDrivers too; never count them as physical I/O.
            guard connection != "Virtual Interface", IOObjectConformsTo(parent, "IOHDIXHDDrive") == 0 else { continue }
            let characteristics = property(parent, "Device Characteristics") as? [String: Any] ?? [:]
            guard let stats = property(driver, "Statistics") as? [String: NSNumber],
                  let rb = stats["Bytes (Read)"], let wb = stats["Bytes (Write)"],
                  let ro = stats["Operations (Read)"], let wo = stats["Operations (Write)"],
                  let rt = stats["Total Time (Read)"], let wt = stats["Total Time (Write)"] else { continue }
            var child: io_registry_entry_t = 0
            guard IORegistryEntryGetChildEntry(driver, kIOServicePlane, &child) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(child) }
            guard let bsd = property(child, "BSD Name") as? String,
                  property(child, "Whole") as? Bool == true else { continue }
            let model = characteristics["Product Name"] as? String ?? bsd
            disks.append(PhysicalDisk(id: bsd, name: model,
                                      capacity: (property(child, "Size") as? NSNumber)?.doubleValue ?? 0,
                                      connection: connection,
                                      counters: DiskCounters(readBytes: rb.uint64Value, writeBytes: wb.uint64Value,
                                                             reads: ro.uint64Value, writes: wo.uint64Value,
                                                             readTime: rt.uint64Value, writeTime: wt.uint64Value)))
        }
        return disks.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }
}
