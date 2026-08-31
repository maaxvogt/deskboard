import Foundation
import Observation

struct SystemSnapshot {
    var cpuPercent: Double = 0
    var memUsed: UInt64 = 0
    var memTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0
    var netDownBps: Double = 0
    var netUpBps: Double = 0
}

/// Samples CPU, memory, disk and network. CPU and network are rates, so the
/// service keeps the previous sample and diffs.
@Observable
final class SystemStats {
    private(set) var snapshot = SystemSnapshot()

    private var lastCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var lastNetBytes: (rx: UInt64, tx: UInt64, at: Date)?

    func sample() {
        var snap = snapshot
        snap.cpuPercent = sampleCPU() ?? snap.cpuPercent
        snap.memUsed = sampleMemoryUsed() ?? snap.memUsed
        if let disk = sampleDisk() {
            snap.diskFree = disk.free
            snap.diskTotal = disk.total
        }
        if let net = sampleNetworkRates() {
            snap.netDownBps = net.down
            snap.netUpBps = net.up
        }
        snapshot = snap
    }

    // MARK: CPU

    private func sampleCPU() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = (
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
        defer { lastCPUTicks = ticks }
        guard let last = lastCPUTicks else { return nil }
        let busy = (ticks.user - last.user) + (ticks.system - last.system) + (ticks.nice - last.nice)
        let total = busy + (ticks.idle - last.idle)
        guard total > 0 else { return nil }
        return Double(busy) / Double(total) * 100
    }

    // MARK: Memory

    private func sampleMemoryUsed() -> UInt64? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_kernel_page_size)
        // "Used" the way Activity Monitor counts it: app (active + speculative
        // is arguable; keep it simple) + wired + compressed.
        let used = (UInt64(info.active_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)) * pageSize
        return used
    }

    // MARK: Disk

    private func sampleDisk() -> (free: Int64, total: Int64)? {
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey,
        ]), let free = values.volumeAvailableCapacityForImportantUsage,
            let total = values.volumeTotalCapacity else { return nil }
        return (free: free, total: Int64(total))
    }

    // MARK: Network

    private func sampleNetworkRates() -> (down: Double, up: Double)? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }

        var rx: UInt64 = 0, tx: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let name = String(cString: ifa.pointee.ifa_name)
            // Physical interfaces only (en*): skip loopback, tunnels, awdl.
            if name.hasPrefix("en"),
               ifa.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = ifa.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                rx += UInt64(data.pointee.ifi_ibytes)
                tx += UInt64(data.pointee.ifi_obytes)
            }
            cursor = ifa.pointee.ifa_next
        }

        let now = Date()
        defer { lastNetBytes = (rx: rx, tx: tx, at: now) }
        guard let last = lastNetBytes else { return nil }
        let dt = now.timeIntervalSince(last.at)
        guard dt > 0, rx >= last.rx, tx >= last.tx else { return nil }
        return (down: Double(rx - last.rx) / dt, up: Double(tx - last.tx) / dt)
    }
}

// MARK: Formatting helpers

enum ByteFormat {
    static func size(_ bytes: UInt64) -> String {
        size(Int64(bytes))
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        let bits = bytesPerSecond * 8
        switch bits {
        case ..<1_000_000: return String(format: "%.0f Kbit/s", bits / 1_000)
        case ..<1_000_000_000: return String(format: "%.1f Mbit/s", bits / 1_000_000)
        default: return String(format: "%.2f Gbit/s", bits / 1_000_000_000)
        }
    }
}
