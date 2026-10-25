<div align="center">
  <img src="https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/assets/app-icon.png" width="144" alt="Performance Monitor app icon" />

  <h1>Performance Monitor</h1>
  <p><strong>Your Mac's performance, in an interface built for it.</strong></p>
  <p>Processes, CPU, memory, disk, network, and GPU monitoring in a native SwiftUI app.</p>

  <p>
    <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-1d252d?logo=apple&logoColor=white" />
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" />
    <img alt="SwiftUI interface" src="https://img.shields.io/badge/UI-SwiftUI-36b8d4" />
    <img alt="No external dependencies" src="https://img.shields.io/badge/dependencies-zero-a98adb" />
    <img alt="English and Brazilian Portuguese" src="https://img.shields.io/badge/languages-en--US%20%7C%20pt--BR-36b8d4" />
  </p>
</div>

---

A native macOS system monitor with a translucent sidebar, system toolbars, and charts arranged in cards. The interface follows your system's light or dark appearance and adopts **Liquid Glass on macOS 26 and later**, with compatible materials on earlier versions. Performance metrics are collected locally every second and displayed over a 60-second history.

## Take a look

### Processes

A native table with search, filters, sortable columns, and resource usage heatmaps.

![Processes tab showing apps sorted by memory, system usage summaries, and native macOS controls](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/processos.jpg)

### Performance

| CPU by logical processor | Memory and swap |
| :--: | :--: |
| [![Per-processor CPU charts and temperature](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/cpu.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/cpu.jpg) | [![Memory usage, composition, and swap metrics](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/memoria.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/memoria.jpg) |
| **Disk reads and writes** | **GPU and shared memory** |
| [![Disk 0 activity and read/write transfer rates](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/disco.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/disco.jpg) | [![GPU engine utilization and shared memory usage](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/gpu.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/gpu.jpg) |

Real screenshots from macOS on an Apple M5 Mac, captured with the Brazilian Portuguese interface. Click gallery images to view them at full size. Readings reflect the capture time and depend on the hardware and available counters.

## Language settings

Open **Settings** using the toolbar's gear button, the app menu, or **⌘,**. Choose:

- **English (US)** — `en-US`
- **Português (Brasil)** — `pt-BR`

The selection applies immediately without restarting the app and is saved for future launches. Tabs, panels, table columns, actions, dialogs, accessibility labels, and numeric separators follow the selected language. On first launch, the app uses Brazilian Portuguese for a Portuguese system language and English otherwise. Process names and hardware/driver identifiers remain as reported by macOS; system-provided menus may follow the system language.

<p align="center">
  <img src="https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/settings.jpg" width="440" alt="Language settings with English (US) selected" />
</p>

## Processes and Performance

The top tabs switch between **Processes**, a native process table, and **Performance**, the resource charts.

The process table shows name, status, CPU, memory, disk reads and writes, thread count, user, and PID. Click a column header to sort; search by name, PID, or user; filter all processes, apps, background processes, or your own user. Cell shading reflects resource usage.

Select a row to open **Info** or **End process**. Ending a process asks for confirmation and offers normal or forced termination. Only processes owned by the current user are eligible, and the monitor cannot end itself. Process identity and ownership are checked again before sending the signal. Ending a process can discard unsaved work.

The table refreshes every **2 seconds**, only while its tab is active and collection is not paused. CPU follows Activity Monitor's convention: **100% means one logical processor**, so multithreaded processes can exceed 100%. Summary cards show system-wide usage and should not be compared directly with the sum of table percentages. Per-process GPU and network metrics are unavailable; protected processes display “—” for restricted readings.

## What you can monitor

| Panel | Live metrics |
| :-- | :-- |
| **CPU** | Overall or per-logical-processor utilization, kernel times, temperature, and uptime. |
| **Memory** | Physical memory usage and composition, cache, available, wired, compressed, and used/allocated swap with swap-in/out rates. |
| **Disk** | Read/write rates, estimated activity, average I/O time, and IOPS. Each physical device appears in the sidebar as Disk 0, Disk 1, and so on. |
| **Network** | Combined send and receive rates across non-loopback interfaces. |
| **GPU** | Overall utilization, renderer and tiler usage, in-use/allocated memory, and temperature, when exposed by the hardware. |

### A chart for each processor

Right-click the CPU graph and choose **Change graph to → Logical processors**. Enable **Show kernel times** to overlay a dashed line, or choose **Copy summary**. Graph preferences persist across launches.

### GPU and temperatures

The GPU panel displays global driver counters, utilization charts, and memory usage. On Apple Silicon, unified memory is identified as **shared with the CPU**. Temperatures come from identified AppleSMC sensors; the displayed value is the highest available reading for that component.

## Getting started

**Requirements:** macOS 14 or later, Swift 6, and the macOS 26 SDK or later to compile the Liquid Glass APIs. Use Xcode or Command Line Tools with a compatible SDK.

```sh
git clone https://github.com/JVini0166/macos-performance-monitor.git
cd macos-performance-monitor
swift run
```

You can also open `Package.swift` in Xcode and run the **PerformanceMonitor** target.

## Build the `.app`

```sh
bash scripts/build-app.sh
open "dist/Performance Monitor.app"
```

The script builds in Release mode, bundles the app icon and both language catalogs, and creates the application in `dist/`. The signature is local (*ad hoc*); the app is not notarized for distribution. To install it for your user, copy **Performance Monitor.app** to `~/Applications`.

## Controls

| Action | How |
| :-- | :-- |
| Switch sections | Choose **Processes** or **Performance** at the top. |
| Select a resource | Click the resource in the sidebar. |
| Pause or resume | **⌘P** or the toolbar button. |
| Change language | **⌘,** or the gear button → **App language**. |
| Change CPU graph | Right-click the graph or use its grid menu. |
| Toggle sidebar | Use the sidebar button in the window toolbar. |
| Switch disks | Click **Disk 0**, **Disk 1**, etc. in the sidebar. |
| Switch GPUs | Use the GPU panel's selector when multiple devices are available. |

GPU history starts empty; other resources initially contain zeros until new samples fill the charts. Pausing freezes readings and charts. Resuming establishes fresh counter baselines.

## Accuracy and compatibility

The interface uses native macOS components, and the metrics follow macOS architecture.

- **Disk:** read/write rates use counter deltas. Active time is an estimate and may overestimate activity when I/O operations overlap.
- **RAM:** app, cached, and available memory are estimated from kernel pages. Swap usage and allocation come directly from the system.
- **GPU:** counters vary by driver. Encode/decode and dedicated VRAM are unavailable in this version; missing readings are shown as unavailable.
- **Temperature:** maps cover Apple M5 and conventional Intel sensors. Other chips require sensor validation. Missing readings are never replaced with fabricated temperatures.
- **Network:** virtual interfaces and tunnels may cause double counting.

See the [technical notes and references](docs/METRICS.md) for formulas, implementation details, and Microsoft/Apple sources. These technical notes are currently in Portuguese.

## Development

```sh
swift build
swift test
```

Tests cover I/O rates, counter resets, GPU validation, sensor decoding, Mach CPU-time conversion, process identity, live collection/pause, translation catalog parity, interpolation, and locale-specific formatting. Integration tests expect a Mac with a physical disk and Metal GPU; additional sensor checks apply to Apple M5.

```text
Sources/PerformanceMonitor/
├── App.swift                 # App lifecycle, performance panels, charts
├── NativeStyle.swift         # Adaptive surfaces and Liquid Glass controls
├── MonitorRootView.swift     # Processes / Performance tabs
├── SettingsView.swift        # App language settings
├── Localization.swift        # Language selection and localized formatting
├── Resources/                # English and Brazilian Portuguese catalogs
├── ProcessMetrics.swift      # Process collection and identity via libproc
├── ProcessesView.swift       # Table, filters, and process actions
├── Metrics.swift             # System sampling and history
├── DiskMetrics.swift         # Physical disk I/O via IOKit
├── GPUMetrics.swift          # Metal identification and driver counters
├── GPUPerformanceView.swift  # GPU panel
└── TemperatureReader.swift   # AppleSMC sensor reads
```

**Local by default:** no telemetry, external services, third-party libraries, or privileged helper. Collection only reads counters; the app does not change fan controls or system settings. Termination signals are sent only through an explicit process action after confirmation in the interface.

---

An independent project. Not affiliated with Microsoft or Apple.
