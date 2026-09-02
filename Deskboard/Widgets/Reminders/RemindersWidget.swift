import SwiftUI

/// The inTouch "Reminder Chat" widget: shows areas the user exposed to the
/// API in the inTouch app, lets them check items off and add new ones.
struct RemindersWidget: View {
    @State private var client = InTouchClient()
    @State private var newItemText = ""
    @State private var confirmClear = false

    var body: some View {
        WidgetCard("Reminders", tint: Theme.tintReminders) {
            content
        } accessory: {
            HStack(spacing: 8) {
                if client.areas.count > 1 {
                    Picker("", selection: Binding(
                        get: { client.selectedArea ?? "" },
                        set: { client.selectedArea = $0 }
                    )) {
                        ForEach(client.areas) { area in
                            Text(area.name).tag(area.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                }
                if client.doneCount > 0 {
                    Button {
                        confirmClear = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete completed items")
                    .confirmationDialog(
                        "Delete \(client.doneCount) completed \(client.doneCount == 1 ? "item" : "items")?",
                        isPresented: $confirmClear, titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) { Task { await client.deleteDone() } }
                    } message: {
                        Text("They are removed in the inTouch app as well.")
                    }
                }
            }
        }
        .task {
            await client.refresh()
            // Items im 10-s-Takt (fühlbar live), Bereichs-Liste jede Minute.
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                tick += 1
                if tick % 6 == 0 {
                    await client.refresh()
                } else {
                    await client.loadItems()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !client.configured {
            WidgetPlaceholder(text: "Add your inTouch API key in Settings")
        } else if let error = client.error, client.areas.isEmpty {
            WidgetPlaceholder(text: error)
        } else if client.areas.isEmpty {
            WidgetPlaceholder(text: "No areas exposed — enable API access per area in the inTouch app")
        } else {
            VStack(spacing: 8) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(client.items) { item in
                            if item.type == "heading" {
                                Text(item.text.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .kerning(0.6)
                                    .foregroundStyle(Theme.faint)
                                    .padding(.top, 6)
                            } else {
                                itemRow(item)
                            }
                        }
                        if client.items.isEmpty {
                            Text("Nothing here yet")
                                .font(Theme.caption)
                                .foregroundStyle(Theme.faint)
                                .padding(.top, 8)
                        }
                    }
                }
                inputRow
            }
        }
    }

    private func itemRow(_ item: ReminderItemDTO) -> some View {
        Button {
            Task { await client.setDone(item, done: !item.done) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.done ? Theme.ok : Theme.muted)
                Text(item.text)
                    .font(Theme.body)
                    .foregroundStyle(item.done ? Theme.faint : Theme.text)
                    .strikethrough(item.done, color: Theme.faint)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }

    private var inputRow: some View {
        HStack(spacing: 6) {
            TextField("Add a reminder…", text: $newItemText)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .onSubmit(submit)
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(newItemText.isEmpty ? Theme.faint : Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(newItemText.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.fill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func submit() {
        let text = newItemText
        newItemText = ""
        Task { await client.addItem(text) }
    }
}
