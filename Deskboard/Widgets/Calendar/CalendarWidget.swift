import SwiftUI

struct CalendarWidget: View {
    var body: some View {
        WidgetCard("Calendar") {
            WidgetPlaceholder(text: "No events")
        }
    }
}
