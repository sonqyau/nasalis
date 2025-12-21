import AppKit
import Combine
import Darwin
import Foundation
import IOKit
import IOKit.ps
import IOKit.storage

enum IOKitReader {
    struct BatterySummary: Sendable {
        let batteryPercent: Int?
        let isBatteryCharging: Bool

        @inline(__always)
        init(batteryPercent: Int?, isBatteryCharging: Bool) {
            self.batteryPercent = batteryPercent
            self.isBatteryCharging = isBatteryCharging
        }
    }

    private static let emptyResult = BatterySummary(batteryPercent: nil, isBatteryCharging: false)
    private static let typeKey = kIOPSTypeKey as String
    private static let internalBatteryType = kIOPSInternalBatteryType as String
    private static let currentCapacityKey = kIOPSCurrentCapacityKey as String
    private static let maxCapacityKey = kIOPSMaxCapacityKey as String
    private static let isChargingKey = kIOPSIsChargingKey as String

    @inline(__always)
    static func readBatterySummary() async -> BatterySummary {
        readBatterySummarySync()
    }

    private static func readBatterySummarySync() -> BatterySummary {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return emptyResult
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return emptyResult
        }

        for ps in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let type = description[typeKey] as? String,
               type != internalBatteryType
            {
                continue
            }

            let current = description[currentCapacityKey] as? Int
            let max = description[maxCapacityKey] as? Int

            let percent: Int? = if let current, let max, max > 0 {
                (current * 100) / max
            } else {
                current
            }

            let isBatteryCharging = description[isChargingKey] as? Bool ?? false

            return BatterySummary(batteryPercent: percent, isBatteryCharging: isBatteryCharging)
        }

        return emptyResult
    }
}

struct ProcessUsage: Identifiable, Hashable, Sendable {
    enum Trigger: String, Sendable {
        case cpu
        case memory
    }

    let pid: Int32
    let command: String
    let cpuPercent: Double
    let memoryPercent: Double
    let triggers: Set<Trigger>

    var id: Int32 { pid }

    var displayName: String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown Process" }
        let url = URL(fileURLWithPath: trimmed)
        let last = url.lastPathComponent
        return last.isEmpty ? trimmed : last
    }

    var cpuDescription: String {
        cpuPercent.formatted(.percent.precision(.fractionLength(0)))
    }

    var memoryDescription: String {
        memoryPercent.formatted(.percent.precision(.fractionLength(0)))
    }

    var triggeredByCPU: Bool {
        triggers.contains(.cpu)
    }

    var triggeredByMemory: Bool {
        triggers.contains(.memory)
    }
}

struct SystemMetrics: Sendable, Equatable {
    var cpuUsage: Double
    var memoryUsed: Measurement<UnitInformationStorage>
    var memoryTotal: Measurement<UnitInformationStorage>
    var runningProcesses: Int
    var network: NetworkMetrics
    var disk: DiskMetrics
    var highActivityProcesses: [ProcessUsage]

    var memoryUsage: Double {
        guard memoryTotal.value > 0 else { return 0 }
        return min(max(memoryUsed.converted(to: .bytes).value / memoryTotal.converted(to: .bytes).value, 0), 1)
    }

    static let empty = Self(
        cpuUsage: 0,
        memoryUsed: Measurement(value: 0, unit: .gigabytes),
        memoryTotal: Measurement(value: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824, unit: .gigabytes),
        runningProcesses: 0,
        network: .zero,
        disk: .zero,
        highActivityProcesses: [],
    )
}

extension SystemMetrics {
    var hasLiveData: Bool {
        if self == .empty { return false }
        if runningProcesses > 0 { return true }
        if cpuUsage > 0 { return true }
        if memoryUsed.converted(to: .bytes).value > 0 { return true }
        if disk.totalBytesPerSecond > 0 { return true }
        if network.totalBytesPerSecond > 0 { return true }
        if !highActivityProcesses.isEmpty { return true }
        return false
    }

    var cpuUsagePercentage: Double {
        min(max(cpuUsage, 0), 1)
    }
}

struct NetworkMetrics: Sendable, Equatable {
    var receivedBytesPerSecond: Double
    var sentBytesPerSecond: Double

    var totalBytesPerSecond: Double {
        max(0, receivedBytesPerSecond + sentBytesPerSecond)
    }

    func formattedBytesPerSecond(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(max(bytes, 0)))
    }

    var formattedUpload: String {
        formattedBytesPerSecond(sentBytesPerSecond)
    }

    var formattedDownload: String {
        formattedBytesPerSecond(receivedBytesPerSecond)
    }

    static let zero = Self(
        receivedBytesPerSecond: 0,
        sentBytesPerSecond: 0,
    )
}

struct DiskMetrics: Sendable, Equatable {
    var readBytesPerSecond: Double
    var writeBytesPerSecond: Double

    var totalBytesPerSecond: Double {
        max(0, readBytesPerSecond + writeBytesPerSecond)
    }

    func formattedBytesPerSecond(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(max(bytes, 0)))
    }

    var formattedReadPerSecond: String {
        formattedBytesPerSecond(readBytesPerSecond)
    }

    var formattedWritePerSecond: String {
        formattedBytesPerSecond(writeBytesPerSecond)
    }

    var formattedTotalPerSecond: String {
        formattedBytesPerSecond(totalBytesPerSecond)
    }

    static let zero = Self(
        readBytesPerSecond: 0,
        writeBytesPerSecond: 0,
    )
}

protocol SystemMetricsProviding {
    var highActivityDuration: TimeInterval { get set }
    var highActivityCPUThreshold: Double { get set }
    var highActivityMemoryThreshold: Double { get set }

    func fetchMetrics() -> SystemMetrics
}

final class SystemReader: SystemMetricsProviding {
    private var lastSnapshot: CPUSnapshot?
    private var lastComputedUsage: Double = 0
    private var lastNetworkSnapshot: NetworkSnapshot?
    private var lastNetworkMetrics: NetworkMetrics = .zero
    private var lastDiskSnapshot: DiskIOSnapshot?
    private var lastDiskMetrics: DiskMetrics = .zero
    private var lastHighActivityProcesses: [ProcessUsage] = []
    private var lastMetrics: SystemMetrics = .empty
    private var processActivityStartTimes: [Int32: Date] = [:]
    private let highActivityProcessLimit = 12

    private let excludedInterfacePrefixes = [
        "lo", "utun", "awdl", "vmnet", "bridge", "llw", "ap", "p2p", "gif", "stf", "vnic", "tap", "tun",
    ]

    var highActivityCPUThreshold: Double = 0.8 {
        didSet {
            let clamped = min(max(highActivityCPUThreshold, 0), 1)
            if clamped != highActivityCPUThreshold {
                highActivityCPUThreshold = clamped
                return
            }
            if abs(highActivityCPUThreshold - oldValue) > .ulpOfOne {
                resetHighActivityTracking()
            }
        }
    }

    var highActivityMemoryThreshold: Double = 0.25 {
        didSet {
            let clamped = min(max(highActivityMemoryThreshold, 0), 1)
            if clamped != highActivityMemoryThreshold {
                highActivityMemoryThreshold = clamped
                return
            }
            if abs(highActivityMemoryThreshold - oldValue) > .ulpOfOne {
                resetHighActivityTracking()
            }
        }
    }

    var highActivityDuration: TimeInterval = 60 {
        didSet {
            if highActivityDuration < 0 {
                highActivityDuration = 0
                return
            }
            if abs(highActivityDuration - oldValue) > .ulpOfOne {
                resetHighActivityTracking()
            }
        }
    }

    private func resetHighActivityTracking() {
        processActivityStartTimes.removeAll()
        lastHighActivityProcesses = []
    }

    func fetchMetrics() -> SystemMetrics {
        let timestamp = Date()
        let cpuUsage = readCPUUsage()

        let memoryUsage = readMemoryUsage()
        var usedMemory = memoryUsage?.used ?? lastMetrics.memoryUsed
        var totalMemory = memoryUsage?.total ?? lastMetrics.memoryTotal

        if usedMemory.converted(to: .bytes).value == 0, lastMetrics.hasLiveData {
            usedMemory = lastMetrics.memoryUsed
        }
        if totalMemory.converted(to: .bytes).value == 0, lastMetrics.hasLiveData {
            totalMemory = lastMetrics.memoryTotal
        }

        var processCount = NSWorkspace.shared.runningApplications.count
        if processCount == 0, lastMetrics.hasLiveData {
            processCount = lastMetrics.runningProcesses
        }

        let network = readNetworkUsage()

        var disk = readDiskThroughput()
        if disk.totalBytesPerSecond == 0, lastMetrics.hasLiveData {
            disk = lastMetrics.disk
        }

        if let processes = readTopProcesses() {
            lastHighActivityProcesses = filterHighActivityProcesses(processes, at: timestamp)
        } else if !lastMetrics.highActivityProcesses.isEmpty {
            lastHighActivityProcesses = lastMetrics.highActivityProcesses
        }

        let metrics = SystemMetrics(
            cpuUsage: cpuUsage,
            memoryUsed: usedMemory,
            memoryTotal: totalMemory,
            runningProcesses: processCount,
            network: network,
            disk: disk,
            highActivityProcesses: lastHighActivityProcesses,
        )

        lastMetrics = metrics
        return metrics
    }

    private func readCPUUsage() -> Double {
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount,
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            return lastComputedUsage
        }

        defer {
            let pointer = vm_address_t(bitPattern: info)
            vm_deallocate(mach_task_self_, pointer, vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        let cpuStates = UnsafeBufferPointer(start: info, count: Int(processorInfoCount))
        let stride = Int(CPU_STATE_MAX)

        var totalTicks: UInt64 = 0
        var idleTicks: UInt64 = 0

        for processorIndex in 0 ..< Int(processorCount) {
            let base = processorIndex * stride
            idleTicks += UInt64(cpuStates[base + Int(CPU_STATE_IDLE)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_USER)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_SYSTEM)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_NICE)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_IDLE)])
        }

        let snapshot = CPUSnapshot(totalTicks: totalTicks, idleTicks: idleTicks)
        let usage = snapshot.usage(relativeTo: lastSnapshot)
        lastSnapshot = snapshot
        lastComputedUsage = usage
        return usage
    }

    private func readMemoryUsage() -> (used: Measurement<UnitInformationStorage>, total: Measurement<UnitInformationStorage>)? {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &vmStat) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &size)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let pageSize: UInt64 = {
            var size: vm_size_t = 0
            let result = host_page_size(mach_host_self(), &size)
            return result == KERN_SUCCESS ? UInt64(size) : 4096
        }()
        let free = UInt64(vmStat.free_count + vmStat.inactive_count) * pageSize
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        let used = max(total - free, 0)

        return (
            used: Measurement(value: Double(used), unit: .bytes),
            total: Measurement(value: Double(total), unit: .bytes),
        )
    }

    private func readNetworkUsage() -> NetworkMetrics {
        guard let snapshot = captureNetworkSnapshot() else {
            return lastNetworkMetrics
        }

        guard let previousSnapshot = lastNetworkSnapshot else {
            lastNetworkSnapshot = snapshot
            lastNetworkMetrics = .zero
            return .zero
        }

        lastNetworkSnapshot = snapshot

        let interval = snapshot.timestamp.timeIntervalSince(previousSnapshot.timestamp)
        guard interval > 0 else {
            return lastNetworkMetrics
        }

        let receivedDelta: UInt64 = if snapshot.receivedBytes >= previousSnapshot.receivedBytes {
            snapshot.receivedBytes - previousSnapshot.receivedBytes
        } else {
            snapshot.receivedBytes
        }

        let sentDelta: UInt64 = if snapshot.sentBytes >= previousSnapshot.sentBytes {
            snapshot.sentBytes - previousSnapshot.sentBytes
        } else {
            snapshot.sentBytes
        }

        let metrics = NetworkMetrics(
            receivedBytesPerSecond: Double(receivedDelta) / interval,
            sentBytesPerSecond: Double(sentDelta) / interval,
        )

        lastNetworkMetrics = metrics
        return metrics
    }

    private func captureNetworkSnapshot() -> NetworkSnapshot? {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
            return nil
        }

        defer {
            freeifaddrs(firstAddress)
        }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = pointer?.pointee {
            if
                let address = current.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                let dataPointer = unsafeBitCast(current.ifa_data, to: UnsafeMutablePointer<if_data>?.self)
            {
                let name = String(cString: current.ifa_name)
                if !excludedInterfacePrefixes.contains(where: { name.hasPrefix($0) }) {
                    received &+= UInt64(dataPointer.pointee.ifi_ibytes)
                    sent &+= UInt64(dataPointer.pointee.ifi_obytes)
                }
            }

            pointer = current.ifa_next
        }

        return NetworkSnapshot(
            receivedBytes: received,
            sentBytes: sent,
            timestamp: Date(),
        )
    }

    private func readDiskThroughput() -> DiskMetrics {
        guard let snapshot = captureDiskSnapshot() else {
            return lastDiskMetrics
        }

        guard let previous = lastDiskSnapshot else {
            lastDiskSnapshot = snapshot
            lastDiskMetrics = .zero
            return lastDiskMetrics
        }

        lastDiskSnapshot = snapshot

        let interval = snapshot.timestamp.timeIntervalSince(previous.timestamp)
        guard interval > 0 else {
            return lastDiskMetrics
        }

        let readDelta = snapshot.readBytes >= previous.readBytes ? snapshot.readBytes - previous.readBytes : snapshot.readBytes
        let writeDelta = snapshot.writeBytes >= previous.writeBytes ? snapshot.writeBytes - previous.writeBytes : snapshot.writeBytes

        let metrics = DiskMetrics(
            readBytesPerSecond: Double(readDelta) / interval,
            writeBytesPerSecond: Double(writeDelta) / interval,
        )
        lastDiskMetrics = metrics
        return metrics
    }

    private func captureDiskSnapshot() -> DiskIOSnapshot? {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            return nil
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var read: UInt64 = 0
        var wrote: UInt64 = 0

        let statsKey = kIOBlockStorageDriverStatisticsKey as String
        let bytesReadKey = kIOBlockStorageDriverStatisticsBytesReadKey as String
        let bytesWrittenKey = kIOBlockStorageDriverStatisticsBytesWrittenKey as String

        while case let service = IOIteratorNext(iterator), service != 0 {
            if let property = IORegistryEntryCreateCFProperty(service, statsKey as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSDictionary
            {
                if let bytesRead = property[bytesReadKey] as? NSNumber {
                    read &+= bytesRead.uint64Value
                }
                if let bytesWritten = property[bytesWrittenKey] as? NSNumber {
                    wrote &+= bytesWritten.uint64Value
                }
            }
            IOObjectRelease(service)
        }

        return DiskIOSnapshot(
            readBytes: read,
            writeBytes: wrote,
            timestamp: Date(),
        )
    }

    private func readTopProcesses() -> [ProcessUsage]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,pmem=,comm=", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        let semaphore = DispatchSemaphore(value: 0)
        var capturedData: Data?

        DispatchQueue.global(qos: .userInitiated).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                capturedData = data
                semaphore.signal()
            }
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        let waitResult = semaphore.wait(timeout: .now() + 2.0)

        if waitResult == .timedOut {
            process.terminate()
            return nil
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0, let finalData = capturedData else { return nil }

        guard let output = String(data: finalData, encoding: .utf8) else {
            return nil
        }

        let lines = output.split(separator: "\n")
        var usages: [ProcessUsage] = []
        usages.reserveCapacity(highActivityProcessLimit)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4 else { continue }

            guard
                let pidValue = Int32(parts[0]),
                let cpuValue = Double(parts[1]),
                let memoryValue = Double(parts[2])
            else {
                continue
            }

            let command = String(parts[3])
            let normalizedCPU = max(cpuValue / 100, 0)
            let normalizedMemory = min(max(memoryValue / 100, 0), 1)
            let exceedsCPU = normalizedCPU >= highActivityCPUThreshold
            let exceedsMemory = normalizedMemory >= highActivityMemoryThreshold
            guard exceedsCPU || exceedsMemory else { continue }

            var triggers: Set<ProcessUsage.Trigger> = []
            if exceedsCPU { triggers.insert(.cpu) }
            if exceedsMemory { triggers.insert(.memory) }

            let usage = ProcessUsage(
                pid: pidValue,
                command: command,
                cpuPercent: normalizedCPU,
                memoryPercent: normalizedMemory,
                triggers: triggers,
            )

            usages.append(usage)
            if usages.count >= highActivityProcessLimit { break }
        }

        return usages
    }

    private func filterHighActivityProcesses(_ processes: [ProcessUsage], at timestamp: Date) -> [ProcessUsage] {
        let activePIDs = Set(processes.map(\.pid))

        for pid in activePIDs where processActivityStartTimes[pid] == nil {
            processActivityStartTimes[pid] = timestamp
        }

        let trackedPIDs = Set(processActivityStartTimes.keys)
        for pid in trackedPIDs.subtracting(activePIDs) {
            processActivityStartTimes.removeValue(forKey: pid)
        }

        guard highActivityDuration > 0 else {
            return processes
        }

        return processes.filter { process in
            guard let start = processActivityStartTimes[process.pid] else { return false }
            return timestamp.timeIntervalSince(start) >= highActivityDuration
        }
    }
}

final class SystemMonitor: ObservableObject, @unchecked Sendable {
    @Published private(set) var metrics: SystemMetrics = .empty

    private var provider: SystemMetricsProviding
    private var timerCancellable: AnyCancellable?
    private let queue: DispatchQueue = .init(label: "system-monitor.queue")
    private var isMonitoring = false

    init(
        metrics: SystemMetrics = .empty,
        autoStart: Bool = true,
        interval: TimeInterval = 5,
        provider: SystemMetricsProviding = SystemReader(),
        highActivityDuration: TimeInterval = 60,
    ) {
        self.provider = provider
        self.provider.highActivityDuration = highActivityDuration
        _metrics = Published(initialValue: metrics)
        if autoStart { startMonitoring(interval: interval) }
    }

    func startMonitoring(interval: TimeInterval = 5) {
        stopMonitoring()
        guard interval > 0 else { return }
        isMonitoring = true

        fetchMetricsOnce()

        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchMetricsOnce()
            }
    }

    func stopMonitoring() {
        timerCancellable?.cancel()
        timerCancellable = nil
        isMonitoring = false
    }

    func ingest(metrics: SystemMetrics) {
        update(with: metrics)
    }

    private func update(with metrics: SystemMetrics) {
        Task { @MainActor in
            self.metrics = metrics
        }
    }

    private func fetchMetricsOnce() {
        queue.async { [weak self] in
            guard let self else { return }
            let metrics = provider.fetchMetrics()
            Task { @MainActor in
                self.update(with: metrics)
            }
        }
    }

    var highActivityDuration: TimeInterval {
        get { provider.highActivityDuration }
        set { provider.highActivityDuration = newValue }
    }

    var highActivityCPUThreshold: Double {
        get { provider.highActivityCPUThreshold }
        set { provider.highActivityCPUThreshold = max(0, min(1, newValue)) }
    }

    var highActivityMemoryThreshold: Double {
        get { provider.highActivityMemoryThreshold }
        set { provider.highActivityMemoryThreshold = max(0, min(1, newValue)) }
    }
}

private struct CPUSnapshot {
    let totalTicks: UInt64
    let idleTicks: UInt64

    func usage(relativeTo previous: Self?) -> Double {
        guard let previous else { return 0 }

        let totalDelta = Double(totalTicks) - Double(previous.totalTicks)
        let idleDelta = Double(idleTicks) - Double(previous.idleTicks)
        guard totalDelta > 0 else { return 0 }

        let busy = totalDelta - idleDelta
        return max(0, min(1, busy / totalDelta))
    }
}

private struct NetworkSnapshot {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let timestamp: Date
}

private struct DiskIOSnapshot {
    let readBytes: UInt64
    let writeBytes: UInt64
    let timestamp: Date
}
