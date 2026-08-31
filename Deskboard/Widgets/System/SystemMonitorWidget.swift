import SwiftUI

struct SystemMonitorWidget: View {
    @State private var stats = SystemStats()

    var body: some View {
        WidgetCard("System", tint: Theme.tintSystem) {
            VStack(alignment: .leading, spacing: 12) {
                gauge(label: "CPU",
                      fraction: stats.snapshot.cpuPercent / 100,
                      detail: String(format: "%.0f %%", stats.snapshot.cpuPercent))

                gauge(label: "Memory",
                      fraction: Double(stats.snapshot.memUsed) / Double(max(stats.snapshot.memTotal, 1)),
                      detail: "\(ByteFormat.size(stats.snapshot.memUsed)) of \(ByteFormat.size(stats.snapshot.memTotal))")

                gauge(label: "Disk",
                      fraction: 1 - Double(stats.snapshot.diskFree) / Double(max(stats.snapshot.diskTotal, 1)),
                      detail: "\(ByteFormat.size(stats.snapshot.diskFree)) free")

                HStack(spacing: 16) {
                    networkItem(symbol: "arrow.down", value: ByteFormat.rate(stats.snapshot.netDownBps))
                    networkItem(symbol: "arrow.up", value: ByteFormat.rate(stats.snapshot.netUpBps))
                }
            }
        }
        .task {
            stats.sample()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                stats.sample()
            }
        }
    }

    private func gauge(label: String, fraction: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(detail)
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill)
                    Capsule()
                        .fill(barColor(fraction))
                        .frame(width: max(4, geo.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 5)
            .animation(.easeOut(duration: 0.4), value: fraction)
        }
    }

    private func barColor(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.7: return Theme.accent
        case ..<0.9: return Theme.warn
        default: return Theme.bad
        }
    }

    private func networkItem(symbol: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(Theme.caption.monospacedDigit())
                .foregroundStyle(Theme.text)
        }
    }
}
