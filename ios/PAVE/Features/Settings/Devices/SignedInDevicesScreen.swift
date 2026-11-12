import PAVECore
import SwiftUI

/// Instellingen › Ingelogde apparaten: this device on top, the others below with a button each to sign them out, and
/// one to sign out everywhere else at once.
struct SignedInDevicesScreen: View {
    @Environment(SignedInDevicesModel.self) private var model
    @State private var deviceToSignOut: SignedInDevice?
    @State private var confirmsAllOthers = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(DevicesMessages.intro)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                content
            }
            .padding(.horizontal, 23)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .animation(.snappy(duration: 0.3), value: model.devices)
            .animation(.snappy(duration: 0.3), value: model.state)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(DevicesMessages.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
        .confirmationDialog(
            deviceToSignOut.map(DevicesMessages.signOutQuestion) ?? "",
            isPresented: Binding(get: { deviceToSignOut != nil }, set: { if !$0 { deviceToSignOut = nil } }),
            titleVisibility: .visible,
            presenting: deviceToSignOut
        ) { device in
            Button("Uitloggen", role: .destructive) { Task { await model.signOut(device) } }
        } message: { _ in
            Text(DevicesMessages.signOutMessage)
        }
        .confirmationDialog(DevicesMessages.signOutAllQuestion, isPresented: $confirmsAllOthers, titleVisibility: .visible) {
            Button("Overal anders uitloggen", role: .destructive) { Task { await model.signOutOthers() } }
        } message: {
            Text(DevicesMessages.signOutMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .frame(height: 64)
            }
            .accessibilityLabel("Apparaten laden")
        case .unavailable:
            PaveEmptyState(icon: .iconDevicePhoneMobileSolid, title: DevicesMessages.unavailableTitle, message: DevicesMessages.unavailableMessage)
                .padding(.top, 24)
        case .notSetUp:
            PaveEmptyState(icon: .iconDevicePhoneMobileSolid, title: DevicesMessages.notSetUpTitle, message: DevicesMessages.notSetUpMessage)
                .padding(.vertical, 24)
            signOutAllButton
        case .failed(let error):
            VStack(spacing: 20) {
                PaveEmptyState(icon: .iconExclamationCircleSolid, title: DevicesMessages.loadFailedTitle, message: DevicesMessages.message(for: error))
                PaveSecondaryButton(title: "Opnieuw proberen", icon: .iconArrowPath) { Task { await model.load() } }
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        case .ready:
            list
        }
    }

    @ViewBuilder
    private var list: some View {
        if let problem = model.problem {
            PaveInlineError(message: problem)
                .padding(.horizontal, 8)
                .transition(.opacity)
        }
        if let current = model.current {
            heading(DevicesMessages.thisDevice)
            SignedInDeviceRow(device: current)
        }
        heading(DevicesMessages.otherDevices)
            .padding(.top, model.current == nil ? 0 : 12)
        if model.others.isEmpty {
            Text(DevicesMessages.noOthers)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 8)
                .transition(.opacity)
        } else {
            ForEach(model.others) { device in
                SignedInDeviceRow(device: device, isSigningOut: model.signingOut == device.id || model.signingOut == SignedInDevicesModel.allOthers) {
                    deviceToSignOut = device
                }
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .trailing))))
            }
            signOutAllButton
                .padding(.top, 8)
        }
    }

    private var signOutAllButton: some View {
        PaveActionButton(title: DevicesMessages.signOutAllOthers) { confirmsAllOthers = true }
            .disabled(model.signingOut != nil)
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .padding(.leading, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    NavigationStack {
        SignedInDevicesScreen()
    }
    .environment(SignedInDevicesModel(service: nil))
}
