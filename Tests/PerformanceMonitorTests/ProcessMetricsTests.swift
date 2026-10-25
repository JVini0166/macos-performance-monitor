import XCTest
@testable import PerformanceMonitor

final class ProcessMetricsTests: XCTestCase {
    func testMachTicksAreConvertedOnAppleSilicon() {
        XCTAssertEqual(ProcessReader.nanoseconds(ticks: 24_000_000, numerator: 125, denominator: 3), 1_000_000_000)
        XCTAssertEqual(ProcessReader.nanoseconds(ticks: 1_000_000_000, numerator: 1, denominator: 1), 1_000_000_000)
    }
    func testRatesUseDeltaAndSupportMoreThanOneCore() throws {
        let old = ProcessCounters(cpuNanoseconds: 100, readBytes: 100, writeBytes: 200, sampledAt: 10)
        let current = ProcessCounters(cpuNanoseconds: 3_000_000_100, readBytes: 4196, writeBytes: 8392, sampledAt: 12)
        let rate = try XCTUnwrap(current.rates(since: old))
        XCTAssertEqual(rate.cpu, 150)
        XCTAssertEqual(rate.read, 2048)
        XCTAssertEqual(rate.write, 4096)
    }
    func testCounterResetAndInvalidIntervalsHaveNoRates() {
        let old = ProcessCounters(cpuNanoseconds: 10, readBytes: 10, writeBytes: 10, sampledAt: 10)
        let reset = ProcessCounters(cpuNanoseconds: 0, readBytes: 0, writeBytes: 0, sampledAt: 11)
        XCTAssertNil(reset.rates(since: old))
        XCTAssertNil(old.rates(since: old))
    }
    @MainActor func testProcessCollectionTracksIdentityAndOwnUsage() async throws {
        let store = ProcessMetrics()
        await store.refresh()
        let first = try XCTUnwrap(store.processes.first { $0.pid == getpid() })
        XCTAssertNotNil(first.memory)
        XCTAssertNotNil(first.counters)
        XCTAssertNil(first.cpu, "First sample needs a baseline")
        XCTAssertFalse(store.canTerminate(first), "Monitor cannot terminate itself")
        try await Task.sleep(for: .milliseconds(100))
        await store.refresh()
        let second = try XCTUnwrap(store.processes.first { $0.pid == getpid() })
        XCTAssertEqual(first.id, second.id)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(second.cpu), 0)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(second.read), 0)
        XCTAssertFalse(second.user.isEmpty)
        store.resetBaseline()
        await store.refresh()
        XCTAssertNil(store.processes.first { $0.pid == getpid() }?.cpu)
    }
}
