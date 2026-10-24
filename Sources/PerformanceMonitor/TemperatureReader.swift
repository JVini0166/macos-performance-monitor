import Foundation
import IOKit

struct TemperatureReading {
    let celsius: Double
    let sensors: [String]
    static func formatted(_ reading: Self?) -> String {
        reading.map { String(format: "%.1f °C", $0.celsius) } ?? "Indisponível"
    }
}

/// Read-only AppleSMC protocol. No writes, fan control, or privileged helper.
final class TemperatureReader {
    private var connection: io_connect_t = 0
    private let cpuKeys: [String]
    private let gpuKeys: [String]
    private var keyInfo: [String: (UInt32, String)] = [:]

    init(processor: String) {
        // Model-specific sensor identifiers, cross-checked against Stats' sensor catalog.
        if processor.contains("Apple M5") {
            cpuKeys = ["Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X", "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"]
            gpuKeys = ["Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g"]
        } else if !processor.contains("Apple") {
            cpuKeys = ["TC0P", "TC0D", "TC0E", "TC0F"]
            gpuKeys = ["TG0P", "TG0D"]
        } else {
            // Unknown Apple Silicon sensor maps must not be guessed.
            cpuKeys = []
            gpuKeys = []
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        if IOServiceOpen(service, mach_task_self_, 0, &connection) != KERN_SUCCESS { connection = 0 }
    }
    deinit { if connection != 0 { IOServiceClose(connection) } }

    func sampleCPU() -> TemperatureReading? { hottest(cpuKeys) }
    func sampleGPU() -> TemperatureReading? { hottest(gpuKeys) }

    private func hottest(_ keys: [String]) -> TemperatureReading? {
        let readings = keys.compactMap { key -> (String, Double)? in
            guard let value = read(key), value.isFinite, value > 0, value < 130 else { return nil }
            return (key, value)
        }
        guard let hottest = readings.map(\.1).max() else { return nil }
        return TemperatureReading(celsius: hottest, sensors: readings.map(\.0))
    }

    private func call(key: String, command: UInt8, size: UInt32 = 0) -> Data? {
        guard connection != 0, key.utf8.count == 4 else { return nil }
        // SMCKeyData ABI: key @0, keyInfo.size @28, command @42, payload @48; 80 bytes.
        var input = Data(count: 80)
        let code = key.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        input.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(of: code, toByteOffset: 0, as: UInt32.self)
            buffer.storeBytes(of: size, toByteOffset: 28, as: UInt32.self)
        }
        input[42] = command
        var output = Data(count: 80)
        var outputSize = 80
        let status = input.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { destination in
                IOConnectCallStructMethod(connection, 2, source.baseAddress, 80, destination.baseAddress, &outputSize)
            }
        }
        guard status == KERN_SUCCESS, outputSize == 80, output[40] == 0 else { return nil }
        return output
    }

    private func read(_ key: String) -> Double? {
        let info: (UInt32, String)
        if let cached = keyInfo[key] { info = cached }
        else {
            guard let data = call(key: key, command: 9) else { return nil }
            let size = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 28, as: UInt32.self) }
            let typeCode = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 32, as: UInt32.self) }
            let type = String(bytes: [24, 16, 8, 0].map { UInt8((typeCode >> $0) & 255) }, encoding: .ascii) ?? ""
            guard size > 0, size <= 32 else { return nil }
            info = (size, type)
            keyInfo[key] = info
        }
        guard let data = call(key: key, command: 5, size: info.0) else { return nil }
        return Self.decode(type: info.1, bytes: Array(data[48..<(48 + Int(info.0))]))
    }
    static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "sp78" where bytes.count == 2:
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "flt " where bytes.count == 4:
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            let value = Double(Float(bitPattern: bits))
            return value.isFinite ? value : nil
        default: return nil
        }
    }
}
