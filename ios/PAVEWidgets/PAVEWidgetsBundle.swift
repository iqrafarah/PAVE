import SwiftUI
import WidgetKit

@main
struct PAVEWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AylaWidget()
        TalkToAylaControl()
        NewConversationControl()
    }
}
