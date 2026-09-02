import SwiftUI

struct ClaudeSessionsWidget: View {
    @State private var client = ClaudeStatusClient()
    @State private var usageService = ClaudeUsageService()
    @State private var rateLimits = ClaudeRateLimitService()

    var body: some View {
        WidgetCard("Claude Code", tint: Theme.tintClaude) {
            VStack(alignment: .leading, spacing: 8) {
                content
                rateLimitBars
                usageFooter
            }
        } accessory: {
            HStack(spacing: 5) {
                Circle()
                    .fill(client.connected ? Theme.ok : Theme.faint)
                    .frame(width: 6, height: 6)
                Text(client.connected ? "live" : "offline")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.faint)
            }
        }
        .task {
            await client.start()
        }
        .task {
            await usageService.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await usageService.refresh()
            }
        }
        .task {
            await rateLimits.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                await rateLimits.refresh()
            }
        }
        .onDisappear {
            client.stop()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = client.error, client.tasks.isEmpty {
            WidgetPlaceholder(text: error)
        } else if client.active.isEmpty && client.recent.isEmpty {
            WidgetPlaceholder(text: "No sessions today")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(client.active) { task in
                        SessionRow(task: task, client: client)
                    }
                    if !client.recent.isEmpty {
                        Text("FINISHED TODAY")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(Theme.faint)
                            .padding(.top, client.active.isEmpty ? 0 : 12)
                            .padding(.bottom, 4)
                        ForEach(client.recent.prefix(10)) { task in
                            SessionRow(task: task, client: client)
                        }
                    }
                }
            }
        }
    }

    /// Rate-limit windows, same three bars as `/usage` in Claude Code.
    @ViewBuilder
    private var rateLimitBars: some View {
        if !rateLimits.limits.isEmpty {
            Divider().overlay(Theme.border)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rateLimits.limits) { limit in
                    RateLimitBar(limit: limit)
                }
            }
        } else if let error = rateLimits.error {
            Divider().overlay(Theme.border)
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                Text(error)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
                Spacer()
            }
        }
    }

    /// Today's token usage from the local Claude Code transcripts.
    @ViewBuilder
    private var usageFooter: some View {
        let usage = usageService.usage
        if usage.sessions > 0 {
            Divider().overlay(Theme.border)
            HStack(spacing: 10) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                Text("Today: \(TokenFormat.short(usage.totalIn)) in · \(TokenFormat.short(usage.outputTokens)) out · \(usage.sessions) sessions")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
        }
    }
}

private struct SessionRow: View {
    let task: ClaudeTask
    let client: ClaudeStatusClient

    /// Live sessions heartbeat at least once a minute (PostToolUse hook).
    /// A "running" task without updates for 5 min is most likely a dead shell.
    private var isStalled: Bool {
        task.status == "running" && task.updatedDate < Date().addingTimeInterval(-300)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            StatusDot(status: isStalled ? "stalled" : task.status)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(Theme.bodyMedium)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(statusLabel)
                        .font(Theme.caption)
                        .foregroundStyle(isStalled ? Theme.faint : statusColor)
                    Text("·")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.faint)
                    Text(task.updatedDate, format: .relative(presentation: .named))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.faint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            // Manual overrides — e.g. close out a stalled session from here.
            ForEach(["running", "waiting", "done", "failed"], id: \.self) { status in
                if status != task.status {
                    Button {
                        Task { await client.setStatus(task, to: status) }
                    } label: {
                        Label(menuLabel(for: status), systemImage: menuSymbol(for: status))
                    }
                }
            }
        }
    }

    private func menuLabel(for status: String) -> String {
        switch status {
        case "running": return "Mark as running"
        case "waiting": return "Mark as waiting"
        case "done": return "Mark as done"
        case "failed": return "Mark as failed"
        default: return status
        }
    }

    private func menuSymbol(for status: String) -> String {
        switch status {
        case "running": return "play.circle"
        case "waiting": return "hourglass"
        case "done": return "checkmark.circle"
        case "failed": return "xmark.circle"
        default: return "circle"
        }
    }

    private var statusLabel: String {
        if isStalled { return "Stalled?" }
        switch task.status {
        case "running": return "Running"
        case "waiting": return "Waiting for input"
        case "queued": return "Queued"
        case "done": return "Done"
        case "failed": return "Failed"
        default: return task.status
        }
    }

    private var statusColor: Color {
        switch task.status {
        case "running": return Theme.info
        case "waiting": return Theme.warn
        case "done": return Theme.ok
        case "failed": return Theme.bad
        default: return Theme.muted
        }
    }
}

/// Status indicator; pulses softly while a session is running.
private struct StatusDot: View {
    let status: String
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(status == "running" && pulsing ? 0.35 : 1)
            .animation(
                status == "running"
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear { pulsing = true }
    }

    private var color: Color {
        switch status {
        case "running": return Theme.info
        case "waiting": return Theme.warn
        case "done": return Theme.ok
        case "failed": return Theme.bad
        case "stalled": return Theme.faint
        default: return Theme.muted
        }
    }
}

/// One `/usage`-style row: title + reset time on the left, percent on the
/// right, capsule bar below. Colour shifts to warn/bad as the window fills.
private struct RateLimitBar: View {
    let limit: ClaudeRateLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(limit.title)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let reset = limit.resetLabel {
                    Text("·")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.faint)
                    Text(reset)
                        .font(Theme.caption.monospacedDigit())
                        .foregroundStyle(Theme.faint)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("\(Int(limit.percent.rounded())) %")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill)
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(min(limit.percent, 100)) / 100))
                }
            }
            .frame(height: 5)
        }
    }

    private var color: Color {
        switch limit.percent {
        case 90...: return Theme.bad
        case 70...: return Theme.warn
        default: return Theme.accent
        }
    }
}
