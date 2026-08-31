import Foundation
import IOKit.ps
import Observation

struct DeviceBattery: Identifiable, Equatable {
    let id: String
    var name: String
    var percent: Int
    var charging: Bool
}

/// Battery levels of this Mac (IOKit power sources) and of paired iOS devices
/// (libimobiledevice's `ideviceinfo`, reachable via USB or Finder Wi-Fi sync).
@Observable
final class DeviceBatteryService {
    private(set) var devices: [DeviceBattery] = []
    private(set) var toolAvailable = true

    private let toolDirs = ["/opt/homebrew/bin", "/usr/local/bin"]

    func refresh() async {
        var found: [DeviceBattery] = []
        if let mac = macBattery() {
            found.append(mac)
        }
        let ipads = await Task.detached(priority: .utility) { [self] in
            iosDeviceBatteries()
        }.value
        found.append(contentsOf: ipads)
        devices = found
    }

    // MARK: Mac internal battery

    private func macBattery() -> DeviceBattery? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = (info[kIOPSIsChargingKey] as? Bool) ?? false
            return DeviceBattery(id: "mac", name: "This Mac", percent: capacity * 100 / max, charging: charging)
        }
        return nil // Desktop Macs have no internal battery.
    }

    // MARK: iOS devices via libimobiledevice

    private func iosDeviceBatteries() -> [DeviceBattery] {
        guard let ideviceId = findTool("idevice_id"), let ideviceInfo = findTool("ideviceinfo") else {
            Task { @MainActor in self.toolAvailable = false }
            return []
        }
        var results: [DeviceBattery] = []
        var seen = Set<String>()
        // USB first, then network (Finder “Show when on Wi-Fi” pairing).
        for networkFlag in [false, true] {
            let args = networkFlag ? ["-n"] : ["-l"]
            guard let list = run(ideviceId, args) else { continue }
            for udid in list.split(separator: "\n").map(String.init) where !udid.isEmpty && !seen.contains(udid) {
                var infoArgs = ["-u", udid]
                if networkFlag { infoArgs.append("-n") }
                guard let battery = run(ideviceInfo, infoArgs + ["-q", "com.apple.mobile.battery"]),
                      let percent = intValue("BatteryCurrentCapacity", in: battery) else { continue }
                let name = run(ideviceInfo, infoArgs + ["-k", "DeviceName"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let charging = battery.contains("BatteryIsCharging: true")
                seen.insert(udid)
                results.append(DeviceBattery(
                    id: udid,
                    name: (name?.isEmpty == false ? name! : "iOS device"),
                    percent: percent,
                    charging: charging
                ))
            }
        }
        return results
    }

    private func findTool(_ name: String) -> String? {
        toolDirs.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func run(_ path: String, _ args: [String], timeout: TimeInterval = 8) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }

        // ideviceinfo can hang on an unreachable network device — hard cap.
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(100_000)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func intValue(_ key: String, in text: String) -> Int? {
        for line in text.split(separator: "\n") where line.hasPrefix("\(key):") {
            return Int(line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}
