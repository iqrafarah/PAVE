import SwiftUI
import UserNotifications

/// Instellingen › Meldingen: whether PAVE tells you about a new melding outside the app (banner and badge on the icon).
struct SettingsNotificationsScreen: View {
    @AppStorage(NotificationAlerts.settingKey) private var alertsOn = true
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        SettingsPage(title: "Meldingen") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $alertsOn) {
                    Text("Seintje bij nieuwe meldingen")
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                }
                .tint(.paveAccent)
                Text("Een banner en een cijfer op het icoon van PAVE als je bewijs is beoordeeld of er een verificatieaanvraag binnenkomt. Er staat alleen een titel in, nooit je bewijs of je gesprekken.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(12)
            .background(Color.panel, in: .rect(cornerRadius: 14))

            if alertsOn, status == .denied {
                permissionCard(
                    "Meldingen staan uit in iOS",
                    "Zet ze aan in de Instellingen van je iPhone, anders ziet PAVE ze niet.",
                    button: "Open Instellingen"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            } else if alertsOn, status == .notDetermined {
                permissionCard(
                    "iOS vraagt eerst toestemming",
                    "Tik op de knop; iOS laat dan zijn eigen vraag zien.",
                    button: "Toestemming vragen"
                ) {
                    Task {
                        _ = await NotificationAlerts.requestPermission()
                        status = await NotificationAlerts.status()
                    }
                }
            }

            Text("Gaat PAVE dicht, dan kijkt iOS af en toe zelf of er iets nieuws is. Het kan daarom even duren voor je een melding ziet. Echte pushmeldingen komen later.")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 4)
        }
        .task { status = await NotificationAlerts.status() }
        .onChange(of: alertsOn) { _, isOn in
            if isOn {
                NotificationAlerts.scheduleRefresh()
                Task {
                    if await NotificationAlerts.status() == .notDetermined { _ = await NotificationAlerts.requestPermission() }
                    status = await NotificationAlerts.status()
                }
            } else {
                NotificationAlerts.setBadge(0)
            }
        }
    }

    private func permissionCard(_ title: String, _ message: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(.listTitle)
                .foregroundStyle(Color.ink)
            Text(message)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
            Button(button, action: action)
                .textStyle(.caption)
                .foregroundStyle(Color.paveAccent)
                .buttonStyle(.pave)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }
}
