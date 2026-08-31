import SwiftUI

/// Shared card chrome for every widget: tinted surface (no border), title row
/// in the widget's accent color, consistent padding.
struct WidgetCard<Content: View, Accessory: View>: View {
    let title: String
    let tint: Theme.Tint
    @ViewBuilder var content: Content
    @ViewBuilder var accessory: Accessory

    init(_ title: String,
         tint: Theme.Tint = Theme.tintNeutral,
         @ViewBuilder content: () -> Content,
         @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.tint = tint
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(tint.accent)
                Spacer()
                accessory
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// Small uniform "no data / error" line used by widgets.
struct WidgetPlaceholder: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.faint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
