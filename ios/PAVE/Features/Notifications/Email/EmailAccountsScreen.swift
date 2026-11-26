import SwiftUI

/// Meldingen › E-mail: the connected iCloud Mail account, connecting it, and disconnecting.
struct EmailAccountsScreen: View {
    @Environment(EmailModel.self) private var email
    @State private var showsICloud = false
    @State private var errorMessage: String?
    @State private var disconnecting: EmailAccount?

    var body: some View {
        List {
            if !email.accounts.isEmpty {
                Section {
                    ForEach(email.accounts) { account in
                        HStack(spacing: 12) {
                            EmailProviderIcon(provider: account.provider)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.address)
                                    .textStyle(.bodyMedium)
                                    .foregroundStyle(Color.ink)
                                    .lineLimit(1)
                                Text(account.provider.title)
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.inkMuted)
                            }
                            Spacer(minLength: 8)
                            Button("Ontkoppelen", role: .destructive) { disconnecting = account }
                                .textStyle(.caption)
                                .buttonStyle(.pave)
                        }
                        .listRowBackground(Color.panel)
                    }
                } header: {
                    sectionTitle("Gekoppeld")
                }
            }

            let available = EmailProvider.allCases.filter { email.account(for: $0) == nil }
            if !available.isEmpty {
                Section {
                    ForEach(available) { provider in
                        Button { errorMessage = nil; showsICloud = true } label: {
                            HStack(spacing: 12) {
                                EmailProviderIcon(provider: provider)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.title)
                                        .textStyle(.bodyMedium)
                                        .foregroundStyle(Color.ink)
                                    Text(provider.subtitle)
                                        .textStyle(.caption)
                                        .foregroundStyle(Color.inkMuted)
                                }
                                Spacer(minLength: 8)
                                Image(.iconChevronRight)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(Color.inkMuted)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.panel)
                    }
                } header: {
                    sectionTitle("E-mailaccount koppelen")
                } footer: {
                    Text("Je e-mails verschijnen bij je meldingen. Je kunt ze daar lezen en beantwoorden.")
                        .textStyle(.caption)
                }
            }

            if let errorMessage {
                Section { PaveInlineError(message: errorMessage) }
                    .listRowBackground(Color.clear)
            }

            if email.hasAccounts {
                Section {
                    contactsRow
                        .listRowBackground(Color.panel)
                } header: {
                    sectionTitle("Welke e-mails zie je?")
                } footer: {
                    Text("Je ziet alleen gesprekken met mensen die je eerder mailde of die in je contacten staan. Nieuwsbrieven en automatische berichten komen er niet in.")
                        .textStyle(.caption)
                }
            }

            Section {
                Label {
                    Text("PAVE haalt je e-mail live op bij je provider en bewaart die niet op een server. Je inloggegevens staan alleen in de sleutelhanger van deze iPhone en blijven daar tot je ontkoppelt.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                } icon: {
                    Image(.iconShieldCheckSolid)
                        .renderingMode(.template)
                        .foregroundStyle(Color.paveAccent)
                }
                .listRowBackground(Color.panel)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("E-mail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsICloud) {
            EmailICloudSheet()
        }
        .confirmationDialog(
            "\(disconnecting?.address ?? "Dit account") ontkoppelen?",
            isPresented: Binding(get: { disconnecting != nil }, set: { if !$0 { disconnecting = nil } }),
            titleVisibility: .visible,
            presenting: disconnecting
        ) { account in
            Button("Ontkoppelen", role: .destructive) {
                Task {
                    await email.disconnect(account.provider)
                    PaveHaptics.success()
                }
            }
            Button(ApplyMessages.cancel, role: .cancel) {}
        } message: { account in
            Text("PAVE vergeet je wachtwoord. Je e-mails blijven gewoon in je mailbox. Trek het app-specifieke wachtwoord ook in bij account.apple.com als je het niet meer gebruikt.")
        }
    }

    @ViewBuilder
    private var contactsRow: some View {
        if EmailContacts.isAllowed {
            Text("Mensen uit je contacten komen er ook in")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        } else if EmailContacts.isUndecided {
            Button("Gebruik ook je contacten") { Task { await email.allowContacts() } }
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.paveAccent)
                .buttonStyle(.pave)
        } else {
            Text("PAVE mag niet in je contacten kijken. Je kunt dat aanzetten in de Instellingen van je iPhone.")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .textCase(nil)
    }
}

struct EmailProviderIcon: View {
    let provider: EmailProvider

    var body: some View {
        Image(.iconEnvelopeSolid)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.paveAccent)
            .frame(width: 18, height: 18)
            .frame(width: 36, height: 36)
            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

/// iCloud Mail: the address and an app-specific password, which Apple requires for every app other than its own.
struct EmailICloudSheet: View {
    @Environment(EmailModel.self) private var email
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var address = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var field: Field?

    private enum Field: Hashable {
        case address
        case password
    }

    static let icloudDomains: Set<String> = ["icloud.com", "me.com", "mac.com"]
    private static let outlookDomains: Set<String> = ["hotmail.com", "hotmail.nl", "outlook.com", "outlook.nl", "live.com", "live.nl", "msn.com"]

    /// Why this address cannot be an iCloud Mail address, or nil when it can.
    static func addressProblem(_ address: String) -> String? {
        let domain = address.split(separator: "@").last.map { $0.lowercased().trimmingCharacters(in: .whitespaces) } ?? ""
        if icloudDomains.contains(domain) { return nil }
        if outlookDomains.contains(domain) {
            return "Dit is een Hotmail- of Outlook-adres. PAVE werkt alleen met iCloud Mail: een @icloud.com-, @me.com- of @mac.com-adres."
        }
        return "iCloud Mail werkt alleen met een @icloud.com-, @me.com- of @mac.com-adres. Je gewone Apple-inlogadres werkt hier niet als het van een andere provider is."
    }

    private var canConnect: Bool {
        !isWorking && address.contains("@") && password.replacingOccurrences(of: " ", with: "").count >= 16
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("naam@icloud.com", text: $address)
                        .textStyle(.bodyMedium)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($field, equals: .address)
                        .submitLabel(.next)
                        .onSubmit { field = .password }
                        .accessibilityLabel("E-mailadres")
                    SecureField("xxxx-xxxx-xxxx-xxxx", text: $password)
                        .textStyle(.bodyMedium)
                        .textContentType(.password)
                        .focused($field, equals: .password)
                        .submitLabel(.done)
                        .onSubmit { Task { await connect() } }
                        .accessibilityLabel("App-specifiek wachtwoord")
                } header: {
                    Text("Je iCloud-e-mailadres en een app-specifiek wachtwoord")
                        .textStyle(.caption)
                        .textCase(nil)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Je doet dit maar één keer: PAVE onthoudt het veilig op deze iPhone. Gebruik niet je gewone Apple-wachtwoord. Maak in je browser bij account.apple.com › Inloggen en beveiliging › App-specifieke wachtwoorden een nieuw wachtwoord voor PAVE en plak het hier.")
                            .textStyle(.caption)
                        Button("Ga naar account.apple.com") {
                            if let url = URL(string: "https://account.apple.com/account/manage/section/security") { openURL(url) }
                        }
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                        .buttonStyle(.pave)
                    }
                }
                if let errorMessage {
                    Section { PaveInlineError(message: errorMessage) }
                }
            }
            .tint(.paveAccent)
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("iCloud Mail koppelen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ApplyMessages.cancel) { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "Bezig…" : "Koppelen") { Task { await connect() } }
                        .disabled(!canConnect)
                }
            }
            .onAppear { field = .address }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.canvas)
        .interactiveDismissDisabled(isWorking)
    }

    private func connect() async {
        guard canConnect else { return }
        // An Apple account can sign in with any address, but iCloud Mail only holds Apple's own.
        if let problem = EmailICloudSheet.addressProblem(address) {
            errorMessage = problem
            PaveHaptics.error()
            return
        }
        isWorking = true
        errorMessage = nil
        do {
            try await email.connectICloud(address: address, password: password)
            PaveHaptics.success()
            dismiss()
            // You just chose to get your mail here: now iOS may ask whether PAVE can tell you when new mail arrives.
            if NotificationAlerts.isEnabled, await NotificationAlerts.status() == .notDetermined {
                _ = await NotificationAlerts.requestPermission()
            }
            NotificationAlerts.scheduleRefresh()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? EmailError.network.errorDescription
            PaveHaptics.error()
        }
        isWorking = false
    }
}
