import SwiftUI
import Observation

@Observable
final class EmailService {
    private(set) var mails: [MailSummary] = []
    private(set) var unseen = 0
    private(set) var error: String?
    private(set) var configured = false

    func refresh() async {
        if Demo.active {
            configured = true
            mails = Demo.mails
            unseen = mails.filter(\.unread).count
            return
        }
        let settings = AppSettings.shared
        guard !settings.imapHost.isEmpty, !settings.imapUser.isEmpty, !settings.imapPassword.isEmpty else {
            configured = false
            return
        }
        configured = true
        let client = IMAPClient(host: settings.imapHost)
        do {
            let result = try await client.fetchInbox(
                user: settings.imapUser,
                password: settings.imapPassword
            )
            mails = result.mails
            unseen = result.unseen
            error = nil
        } catch IMAPError.loginFailed {
            error = "Login failed — check credentials"
        } catch {
            self.error = "Mailbox unreachable"
        }
    }
}

struct EmailWidget: View {
    @State private var service = EmailService()

    var body: some View {
        WidgetCard("Mail", tint: Theme.tintMail) {
            content
        } accessory: {
            if service.unseen > 0 {
                Text("\(service.unseen) unread")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
        .task {
            await service.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(180))
                await service.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !service.configured {
            WidgetPlaceholder(text: "Configure IMAP in Settings")
        } else if let error = service.error, service.mails.isEmpty {
            WidgetPlaceholder(text: error)
        } else if service.mails.isEmpty {
            WidgetPlaceholder(text: "Inbox is empty")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(service.mails) { mail in
                        row(mail)
                        if mail.id != service.mails.last?.id {
                            Divider().overlay(Theme.border)
                        }
                    }
                }
            }
        }
    }

    private func row(_ mail: MailSummary) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(mail.unread ? Theme.accent : .clear)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(mail.from)
                        .font(mail.unread ? Theme.bodyMedium : Theme.body)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    if let date = mail.date {
                        Text(shortDate(date))
                            .font(Theme.caption)
                            .foregroundStyle(Theme.faint)
                    }
                }
                Text(mail.subject)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    private func shortDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
