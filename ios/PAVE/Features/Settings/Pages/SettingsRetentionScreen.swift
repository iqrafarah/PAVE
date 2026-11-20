import PAVECore
import SwiftUI

/// Instellingen › Gegevens bewaren: after how long chats disappear by themselves ("verval", as in WhatsApp), which
/// chats stay anyway, and what Ayla may do with your archive. Nothing expires unless you choose it; deleting is final,
/// so a choice that can delete chats at once is asked first, as on the web.
struct SettingsRetentionScreen: View {
    @Environment(ProfileModel.self) private var profile
    /// A choice that deletes more than before, waiting for Ja.
    @State private var pending: PaveRetention?

    var body: some View {
        SettingsPage(title: RetentionMessages.title) {
            switch profile.retentionState {
            case .ready:
                if let retention = profile.retention {
                    expiryCard(retention)
                    archiveCard(retention)
                }
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text(RetentionMessages.loading)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(12)
            case .notSetUp:
                note(RetentionMessages.notAvailable)
            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    PaveInlineError(message: RetentionMessages.loadFailed)
                    Button("Opnieuw proberen") { Task { await profile.load() } }
                        .textStyle(.link)
                        .foregroundStyle(Color.paveAccent)
                        .frame(minHeight: 44)
                }
                .padding(12)
            }
        }
        .task { await profile.load() }
        .confirmationDialog(
            RetentionMessages.confirmTitle,
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { chosen in
            Button(RetentionMessages.confirmButton, role: .destructive) { save(chosen) }
        } message: { chosen in
            Text(RetentionMessages.confirmMessage(chosen.chatExpiry))
        }
        .alert("Dat lukte niet", isPresented: Binding(get: { profile.problem != nil }, set: { if !$0 { profile.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(profile.problem ?? "")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 14))
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

    /// Title left, choice right. The choice keeps its own width and never breaks; a long title wraps beside it, so the
    /// row fits on every screen width and text size.
    private func row(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            rowTitle(title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            picker()
                .labelsHidden()
                .tint(.paveAccent)
                .fixedSize()
        }
        .frame(minHeight: 44)
    }

    private func rowTitle(_ title: String) -> some View {
        Text(title)
            .textStyle(.listTitle)
            .foregroundStyle(Color.ink)
    }

    private func toggle(_ title: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { rowTitle(title) }
            .tint(.paveAccentFill)
            .frame(minHeight: 44)
    }

    /// One choice of the settings; it saves at once, unless it can delete chats that were kept until now.
    private func binding<Value: Equatable>(_ retention: PaveRetention, _ keyPath: WritableKeyPath<PaveRetention, Value>) -> Binding<Value> {
        Binding(
            get: { retention[keyPath: keyPath] },
            set: { value in
                var chosen = retention
                chosen[keyPath: keyPath] = value
                PaveHaptics.selection()
                if Self.deletesMore(chosen.chatExpiry, than: retention.chatExpiry) {
                    pending = chosen
                } else {
                    save(chosen)
                }
            }
        )
    }

    private func save(_ chosen: PaveRetention) {
        Task { await profile.setRetention(chosen) }
    }

    /// A shorter time, counting from making the chat instead of its last message, or no longer keeping pinned or
    /// locked chats: chats that stayed until now can go at once.
    static func deletesMore(_ new: ChatExpiry, than old: ChatExpiry) -> Bool {
        guard let days = new.days else { return false }
        if old.days.map({ days < $0 }) ?? true { return true }
        if new.start == .created, old.start == .lastMessage { return true }
        if !new.keepsPinned, old.keepsPinned { return true }
        if !new.keepsLocked, old.keepsLocked { return true }
        return false
    }
}

#Preview {
    NavigationStack { SettingsRetentionScreen() }
        .environment(ProfileModel(service: nil))
}
