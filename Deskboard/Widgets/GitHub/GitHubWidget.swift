import SwiftUI

struct GitHubWidget: View {
    var body: some View {
        WidgetCard("GitHub") {
            WidgetPlaceholder(text: "Configure token in Settings")
        }
    }
}
