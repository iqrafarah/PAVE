import PAVECore
import SwiftUI

/// Instellingen › Gegevens bewaren: after how long chats disappear by themselves ("verval", as in WhatsApp), which
/// chats stay anyway, and what Ayla may do with your archive. Nothing expires unless you choose it; deleting is final.
struct SettingsRetentionScreen: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        SettingsPage(title: RetentionMessages.title) {
            if let retention = profile.retention {
                expiryCard(retention)
                archiveCard(retention)
            } else {
                Text(RetentionMessages.notAvailable)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.panel, in: .rect(cornerRadius: 14))
            }
        }
        .task { await profile.load() }
    }

    private func expiryCard(_ retention: PaveRetention) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            row("Chats laten vervallen") {
                Picker("Chats laten vervallen", selection: binding(retention, \.chatExpiry.days)) {
                    Text(RetentionMessages.noExpiry).tag(Int?.none)
                    ForEach(ChatExpiry.periods, id: \.self) { days in
                        Text(RetentionMessages.period(days)).tag(Int?.some(days))
                    }
                }
            }
            Text(RetentionMessages.expiryHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            if retention.chatExpiry.days != nil {
                Divider()
                row("De tijd loopt vanaf") {
                    Picker("De tijd loopt vanaf", selection: binding(retention, \.chatExpiry.start)) {
                        ForEach(ChatExpiry.Start.allCases) { start in
                            Text(RetentionMessages.start(start)).tag(start)
                        }
                    }
                }
                toggle("Vastgezette chats bewaren", binding(retention, \.chatExpiry.keepsPinned))
                toggle("Vergrendelde chats bewaren", binding(retention, \.chatExpiry.keepsLocked))
                Text(RetentionMessages.neverExpires)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.panel, in: .rect(cornerRadius: 14))
        .animation(.easeOut(duration: 0.2), value: retention.chatExpiry.days != nil)
    }

    private func archiveCard(_ retention: PaveRetention) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            toggle("Ayla mag je archief gebruiken", binding(retention, \.aylaUsesArchive))
            Text(RetentionMessages.aylaArchiveHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }

    private func row(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                rowTitle(title)
                Spacer(minLength: 8)
                picker().labelsHidden().tint(.paveAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                rowTitle(title)
                picker().labelsHidden().tint(.paveAccent)
            }
        }
    }

    private func rowTitle(_ title: String) -> some View {
        Text(title)
            .textStyle(.listTitle)
            .foregroundStyle(Color.ink)
    }

    private func toggle(_ title: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { rowTitle(title) }
            .tint(.paveAccent)
            .frame(minHeight: 44)
    }

    /// One choice of the settings; choosing saves at once.
    private func binding<Value: Equatable>(_ retention: PaveRetention, _ keyPath: WritableKeyPath<PaveRetention, Value>) -> Binding<Value> {
        Binding(
            get: { retention[keyPath: keyPath] },
            set: { value in
                var chosen = retention
                chosen[keyPath: keyPath] = value
                PaveHaptics.selection()
                Task { await profile.setRetention(chosen) }
            }
        )
    }
}

#Preview {
    NavigationStack { SettingsRetentionScreen() }
        .environment(ProfileModel(service: nil))
}
