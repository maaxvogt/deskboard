import SwiftUI

struct DeviceBatteryWidget: View {
    @State private var service = DeviceBatteryService()

    var body: some View {
        WidgetCard("Batteries", tint: Theme.tintBattery) {
            if service.devices.isEmpty {
                WidgetPlaceholder(text: service.toolAvailable
                    ? "No devices found. Enable “Show this iPad when on Wi-Fi” in Finder."
                    : "libimobiledevice not installed (brew install libimobiledevice)")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(service.devices) { device in
                        row(device)
                    }
                }
            }
        }
        .task {
            await service.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await service.refresh()
            }
        }
    }

    private func row(_ device: DeviceBattery) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(device.name)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer()
                if device.charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.ok)
                }
                Text("\(device.percent) %")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill)
                    Capsule()
                        .fill(color(for: device))
                        .frame(width: max(4, geo.size.width * CGFloat(device.percent) / 100))
                }
            }
            .frame(height: 5)
        }
    }

    private func color(for device: DeviceBattery) -> Color {
        if device.charging { return Theme.ok }
        switch device.percent {
        case ..<20: return Theme.bad
        case ..<40: return Theme.warn
        default: return Theme.accent
        }
    }
}
