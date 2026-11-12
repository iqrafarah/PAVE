import PAVECore
import SwiftUI

/// Step 4: the evidence is in the vault. A big tick lands, then the box for Ayla turns in and its sentence is revealed,
/// as in the Figma animation. The box starts empty: Ayla only gets in when you tick it yourself.
struct VaultEvidenceAddedView: View {
    @Bindable var flow: VaultAddEvidenceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var consentShown = false

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text(VaultMessages.added)
                    .textStyle(.welcomeTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.addedMessage)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            tick
            if flow.coverWaits {
                PaveNotice(message: VaultMessages.coverNotYet)
            }
            consent
        }
        .frame(maxWidth: .infinity)
        .task {
            guard !landed else { return }
            if reduceMotion {
                landed = true
                consentShown = true
                return
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) { landed = true }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.5)) { consentShown = true }
        }
    }

    private var tick: some View {
        Image(.iconCheck)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 50, height: 50)
            .foregroundStyle(.white)
            .scaleEffect(landed ? 1 : 0.4)
            .opacity(landed ? 1 : 0)
            .frame(width: 112, height: 112)
            .background(Color.brandGreen, in: .circle)
            .scaleEffect(landed ? 1 : 0.6)
            .opacity(landed ? 1 : 0)
            .accessibilityHidden(true)
    }

    private var consent: some View {
        Button {
            PaveHaptics.selection()
            flow.allowsAyla.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PaveCheckbox(isOn: flow.allowsAyla, size: 18)
                    .rotationEffect(.degrees(consentShown ? 0 : -180))
                    .padding(.top, 1)
                Text(VaultMessages.aylaConsent(hasFile: flow.document != nil))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(flow.allowsAyla ? Color.brandGreen : .ink)
                    .multilineTextAlignment(.leading)
                    .mask(alignment: .leading) {
                        // The sentence is uncovered from left to right, like the white band sliding away in Figma.
                        GeometryReader { proxy in
                            Rectangle().frame(width: consentShown ? proxy.size.width : 0)
                        }
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: consentShown)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .opacity(consentShown ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: flow.allowsAyla)
        .accessibilityLabel(VaultMessages.aylaConsent(hasFile: flow.document != nil))
        .accessibilityValue(flow.allowsAyla ? "Aan" : "Uit")
        .accessibilityAddTraits(.isToggle)
    }
}

#Preview {
    VaultEvidenceAddedView(flow: VaultAddEvidenceModel(vault: VaultModel(previewContents: .preview), category: .projects, folderID: nil))
        .padding(24)
}
