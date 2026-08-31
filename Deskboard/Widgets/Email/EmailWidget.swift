import SwiftUI

struct EmailWidget: View {
    var body: some View {
        WidgetCard("Mail") {
            WidgetPlaceholder(text: "Configure IMAP in Settings")
        }
    }
}
