// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PerformanceMonitor",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PerformanceMonitor", resources: [.process("Resources")]),
        .testTarget(name: "PerformanceMonitorTests", dependencies: ["PerformanceMonitor"])
    ],
    swiftLanguageModes: [.v5]
)
