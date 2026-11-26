import SwiftUI
import WidgetKit

@main
struct PAVEWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AylaWidget()
        ApplicationsWidget()
        TalkToAylaControl()
        NewConversationControl()
        StopSharingControl()
        AylaVoiceLiveActivity()
        PlanLiveActivity()
    }
}
