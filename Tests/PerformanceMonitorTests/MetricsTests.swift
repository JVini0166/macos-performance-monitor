import XCTest
@testable import PerformanceMonitor

final class MetricsTests: XCTestCase {
    func testGPUCountersPreserveMissingDataAndRejectInvalidValues() {
        XCTAssertNil(GPUReading.percentage(nil))
        XCTAssertNil(GPUReading.percentage(NSNumber(value: Double.nan)))
        XCTAssertNil(GPUReading.percentage(101))
        XCTAssertEqual(GPUReading.percentage(0), 0)
        XCTAssertEqual(GPUReading.percentage(100), 100)
        XCTAssertNil(GPUReading.memory(-1))
        XCTAssertNil(GPUReading.memory(nil))
        XCTAssertEqual(GPUReading.memory(1_048_576), 1_048_576)
    }
    func testTemperatureDecoding() throws {
        XCTAssertEqual(try XCTUnwrap(TemperatureReader.decode(type: "sp78", bytes: [55, 128])), 55.5)
        XCTAssertEqual(try XCTUnwrap(TemperatureReader.decode(type: "sp78", bytes: [255, 128])), -0.5)
        let bits = Float(62.25).bitPattern
        let bytes = (0..<4).map { UInt8((bits >> ($0 * 8)) & 255) }
        XCTAssertEqual(try XCTUnwrap(TemperatureReader.decode(type: "flt ", bytes: bytes)), 62.25)
        XCTAssertNil(TemperatureReader.decode(type: "flt ", bytes: [0]))
        XCTAssertNil(TemperatureReader.decode(type: "ui32", bytes: bytes))
        XCTAssertEqual(TemperatureReading.formatted(nil), "Indisponível")
    }
    func testDiskRatesUseIntervalDeltasAndNanoseconds() throws {
        let old = DiskCounters(readBytes: 100, writeBytes: 200, reads: 10, writes: 20, readTime: 100, writeTime: 200)
        let new = DiskCounters(readBytes: 2148, writeBytes: 4296, reads: 12, writes: 22, readTime: 100_000_100, writeTime: 300_000_200)
        let rate = try XCTUnwrap(new.rates(since: old, elapsed: 2))
        XCTAssertEqual(rate.read, 1024)
        XCTAssertEqual(rate.write, 2048)
        XCTAssertEqual(rate.operations, 2)
        XCTAssertEqual(rate.activeEstimate, 20, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(rate.responseMS), 100)
    }
    func testIdleHasNoResponseTimeAndResetDoesNotSpike() throws {
        let old = DiskCounters(readBytes: 100, writeBytes: 200, reads: 10, writes: 20, readTime: 100, writeTime: 200)
        let idle = try XCTUnwrap(old.rates(since: old, elapsed: 1))
        XCTAssertEqual(idle.read, 0)
        XCTAssertEqual(idle.activeEstimate, 0)
        XCTAssertNil(idle.responseMS)
        let reset = DiskCounters(readBytes: 0, writeBytes: 0, reads: 0, writes: 0, readTime: 0, writeTime: 0)
        XCTAssertNil(reset.rates(since: old, elapsed: 1))
        XCTAssertNil(old.rates(since: old, elapsed: 0))
    }
    func testConcurrentIOEstimateIsBounded() throws {
        let old = DiskCounters(readBytes: 0, writeBytes: 0, reads: 0, writes: 0, readTime: 0, writeTime: 0)
        var new = old
        new.readTime = 3_000_000_000
        new.reads = 20
        XCTAssertEqual(try XCTUnwrap(new.rates(since: old, elapsed: 1)).activeEstimate, 100)
    }
    @MainActor func testLiveCollectorsAndPause() async throws {
        let metrics = Metrics()
        try await Task.sleep(for: .milliseconds(1100))
        metrics.sample()
        XCTAssertEqual(metrics.coreHistory.count, metrics.logical)
        XCTAssertTrue(metrics.coreHistory.allSatisfy { $0.count == 60 && $0.allSatisfy { (0...100).contains($0) } })
        XCTAssertGreaterThan(metrics.memoryUsed, 0)
        XCTAssertLessThanOrEqual(metrics.memoryUsed, metrics.memoryTotal)
        XCTAssertEqual(metrics.memoryUsed + metrics.memoryAvailable, metrics.memoryTotal, accuracy: 1)
        XCTAssertLessThanOrEqual(metrics.swapUsed, metrics.swapTotal)
        XCTAssertFalse(metrics.disks.isEmpty, "Expected at least one physical disk on the development Mac")
        XCTAssertTrue(metrics.disks.allSatisfy { $0.connection != "Virtual Interface" })
        XCTAssertNotNil(metrics.selectedDiskRates)
        XCTAssertFalse(metrics.gpus.isEmpty, "Expected a Metal GPU on the development Mac")
        let gpu = try XCTUnwrap(metrics.selectedGPU)
        XCTAssertNotNil(gpu.utilization, "Expected utilization from this Mac's driver")
        XCTAssertGreaterThan(try XCTUnwrap(gpu.memoryInUse), 0)
        XCTAssertEqual(metrics.gpuHistory(.overall).count, 60)
        XCTAssertTrue(metrics.gpuHistory(.overall).allSatisfy { $0.isNaN || (0...100).contains($0) })
        if metrics.processor.contains("Apple M5") {
            XCTAssertNotNil(metrics.cpuTemperature)
            XCTAssertNotNil(metrics.gpuTemperature)
        }
        let cpu = metrics.cpu
        let history = metrics.coreHistory
        let gpuUsage = gpu.utilization
        let gpuMemory = gpu.memoryInUse
        let cpuTemperature = metrics.cpuTemperature?.celsius
        metrics.paused = true
        metrics.sample()
        XCTAssertEqual(metrics.cpu, cpu)
        XCTAssertEqual(metrics.coreHistory, history)
        XCTAssertEqual(metrics.selectedGPU?.utilization, gpuUsage)
        XCTAssertEqual(metrics.selectedGPU?.memoryInUse, gpuMemory)
        XCTAssertEqual(metrics.cpuTemperature?.celsius, cpuTemperature)
        metrics.paused = false
        metrics.sample()
        XCTAssertTrue(metrics.diskRates.isEmpty, "Resume must establish a new baseline")
    }
}
