import SwiftUI

/// Shared card chrome for every widget: title row in the widget's accent color,
/// consistent padding, and a surface that depends on the appearance:
/// - light / dark: pressed into the ground (inner shadows, same colour as background)
/// - darkColor: the widget's tinted surface, no border
struct WidgetCard<Content: View, Accessory: View>: View {
    let title: String
    let tint: Theme.Tint
    @ViewBuilder var content: Content
    @ViewBuilder var accessory: Accessory

    @Environment(\.colorScheme) private var colorScheme

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
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    @ViewBuilder private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        let mode = Theme.mode(for: colorScheme)
        switch mode {
        case .light, .dark:
            shape.fill(
                Theme.card
                    .shadow(.inner(color: Theme.insetShade(for: mode), radius: 6, x: 3, y: 3))
                    .shadow(.inner(color: Theme.insetLight(for: mode), radius: 6, x: -3, y: -3))
            )
        case .darkColor:
            shape.fill(tint.surface)
        }
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
