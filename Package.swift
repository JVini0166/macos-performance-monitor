// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PerformanceMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PerformanceMonitor"),
        .testTarget(name: "PerformanceMonitorTests", dependencies: ["PerformanceMonitor"])
    ],
    swiftLanguageModes: [.v5]
)
