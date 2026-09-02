import SwiftUI

struct GitHubWidget: View {
    @State private var service = GitHubService()

    var body: some View {
        WidgetCard("GitHub", tint: Theme.tintGitHub) {
            content
        }
        .task {
            await service.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await service.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !service.configured {
            WidgetPlaceholder(text: AppSettings.shared.githubUser.isEmpty
                ? "Add your GitHub username in Settings"
                : "No GitHub token — sign in with the gh CLI or add one in Settings")
        } else if let error = service.error, service.events.isEmpty && service.openPRs.isEmpty {
            WidgetPlaceholder(text: error)
        } else if service.events.isEmpty && service.openPRs.isEmpty {
            WidgetPlaceholder(text: service.scopeHint ?? "No open PRs or recent activity")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    if !service.openPRs.isEmpty {
                        sectionLabel("OPEN PULL REQUESTS")
                        ForEach(service.openPRs) { pr in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.triangle.pull")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.ok)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pr.title)
                                        .font(Theme.bodyMedium)
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    Text("\(pr.repo) #\(pr.number)")
                                        .font(Theme.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }

                    if !service.events.isEmpty {
                        sectionLabel("ACTIVITY")
                            .padding(.top, service.openPRs.isEmpty ? 0 : 8)
                        ForEach(service.events.prefix(8)) { event in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.text)
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(event.repo)
                                        .font(Theme.caption)
                                        .foregroundStyle(Theme.muted)
                                    if let date = event.date {
                                        Text(date, format: .relative(presentation: .named))
                                            .font(Theme.caption)
                                            .foregroundStyle(Theme.faint)
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(Theme.faint)
            .padding(.bottom, 2)
    }
}
