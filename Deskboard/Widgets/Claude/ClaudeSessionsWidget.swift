import SwiftUI

struct ClaudeSessionsWidget: View {
    @State private var client = ClaudeStatusClient()

    var body: some View {
        WidgetCard("Claude Code") {
            content
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
        .onDisappear {
            client.stop()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = client.error, client.tasks.isEmpty {
            WidgetPlaceholder(text: error)
        } else if client.active.isEmpty && client.recent.isEmpty {
            WidgetPlaceholder(text: "No sessions")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(client.active) { task in
                        SessionRow(task: task)
                    }
                    if !client.recent.isEmpty {
                        Text("RECENT")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(Theme.faint)
                            .padding(.top, client.active.isEmpty ? 0 : 12)
                            .padding(.bottom, 4)
                        ForEach(client.recent.prefix(8)) { task in
                            SessionRow(task: task)
                        }
                    }
                }
            }
        }
    }
}

private struct SessionRow: View {
    let task: ClaudeTask

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
