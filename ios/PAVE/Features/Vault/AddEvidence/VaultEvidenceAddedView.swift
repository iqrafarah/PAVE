import PAVECore
import SwiftUI

/// Step 4: the evidence is in the vault. The tick lands, then the card about Ayla rises in. It starts off: Ayla only
/// takes the evidence along when you switch it on. Lower parts on a short screen, so it never feels cramped.
struct VaultEvidenceAddedView: View {
    @Bindable var flow: VaultAddEvidenceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isShortSheet) private var isShort
    @State private var landed = false
    @State private var consentShown = false

    var body: some View {
        VStack(spacing: isShort ? 14 : 22) {
            Spacer(minLength: 0)
            tick
            VStack(spacing: 8) {
                Text(VaultMessages.added)
                    .textStyle(isShort ? .emptyTitle : .welcomeTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.addedMessage)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            if flow.coverWaits {
                PaveNotice(message: VaultMessages.coverNotYet)
            }
            Spacer(minLength: 0)
            VaultAylaConsentCard(isOn: $flow.allowsAyla, hasFile: flow.hasFile)
                .opacity(consentShown ? 1 : 0)
                .offset(y: consentShown ? 0 : 16)
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
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { consentShown = true }
        }
    }

    private var tick: some View {
        let size: CGFloat = isShort ? 76 : 104
        return Image(.iconCheck)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.42, height: size * 0.42)
            .foregroundStyle(.white)
            .scaleEffect(landed ? 1 : 0.4)
            .frame(width: size, height: size)
            .background(Color.brandGreen, in: .circle)
            .scaleEffect(landed ? 1 : 0.6)
            .opacity(landed ? 1 : 0)
            .accessibilityHidden(true)
    }
}

#Preview {
    VaultEvidenceAddedView(flow: VaultAddEvidenceModel(vault: VaultModel(previewContents: .preview), category: .projects, folderID: nil))
        .padding(24)
}
