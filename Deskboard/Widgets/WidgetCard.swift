import SwiftUI

/// Shared card chrome for every widget: title row, optional status dot,
/// consistent padding, hairline border.
struct WidgetCard<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @ViewBuilder var accessory: Accessory

    init(_ title: String,
         @ViewBuilder content: () -> Content,
         @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(Theme.muted)
                Spacer()
                accessory
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

/// Small uniform "no data / error" line used by widgets.
struct WidgetPlaceholder: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.faint)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
