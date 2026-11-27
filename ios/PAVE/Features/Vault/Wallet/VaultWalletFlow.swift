import PAVECore
import SwiftUI

/// "Haal bewijs uit je wallet" (demo for Npuls) as its own way through "Bewijs toevoegen", with the same header,
/// stepper, sliding pages and buttons: choose cards from the wallet, see each one checked and turn "Geverifieerd", then
/// say whether Ayla may use them.
struct VaultWalletFlow: View {
    @Bindable var wallet: VaultWalletModel
    /// Back to the first step of "Bewijs toevoegen".
    let onBack: () -> Void
    /// Everything is done: the sheet closes.
    let onDone: () -> Void

    @Environment(\.paveReduceMotion) private var reduceMotion
    @Environment(\.isShortSheet) private var isShort
    /// The cards of the check come in one after the other.
    @State private var shownChecking = 0

    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.42)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .push(from: wallet.movesForward ? .trailing : .leading)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .top) {
                page
                    .id(wallet.phase)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            footer
        }
        .animation(pageAnimation, value: wallet.phase)
        .task { if wallet.state == .loading { await wallet.load() } }
        .onChange(of: wallet.phase) { _, phase in
            AccessibilityNotification.Announcement("Stap \(phase.rawValue + 1) van 3: \(VaultMessages.walletSteps[phase.rawValue])").post()
        }
    }

    private var header: some View {
        VStack(spacing: isShort ? 10 : 18) {
            HStack(spacing: 8) {
                Text(VaultMessages.walletTitle)
                    .textStyle(isShort ? .label : .listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.walletDemoTitle)
                    .textStyle(.caption)
                    .foregroundStyle(Color.paveAccent)
                    .padding(.horizontal, 7)
                    .frame(minHeight: 22)
                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 6))
                    .accessibilityLabel(VaultMessages.walletDemoMessage)
                Spacer()
            }
            .frame(height: isShort ? 36 : 44)
            PaveStepper(steps: VaultMessages.walletSteps, current: wallet.phase.rawValue)
        }
        .padding(.horizontal, 24)
        .padding(.top, isShort ? 8 : 22)
        .padding(.bottom, isShort ? 8 : 16)
    }

    @ViewBuilder
    private var page: some View {
        switch wallet.phase {
        case .choose: choosePage
        case .checking: checkingPage
        case .done:
            VaultWalletDoneView(wallet: wallet)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
    }

    // MARK: Kiezen

    @ViewBuilder
    private var choosePage: some View {
        switch wallet.state {
        case .loading:
            VStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.tileFill)
                        .frame(height: 170)
                }
            }
            .paveShimmer()
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .accessibilityLabel(VaultMessages.walletLoading)
        case .failed(let message):
            VStack(spacing: 16) {
                PaveNotice(message: message, tone: .critical)
                PaveSoftButton(title: VaultMessages.walletRetry) { Task { await wallet.load() } }
            }
            .padding(24)
        case .ready:
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(wallet.available.isEmpty ? VaultMessages.walletAllInVault : VaultMessages.walletIntro)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.bottom, 2)
                    if let problem = wallet.problem {
                        PaveNotice(message: problem, tone: .critical)
                    }
                    ForEach(wallet.credentials) { credential in
                        VaultWalletCard(credential: credential, mode: .choose(isSelected: wallet.isSelected(credential))) {
                            PaveHaptics.selection()
                            wallet.toggle(credential)
                        }
                    }
                    PaveIconLabel(icon: .iconInformationCircle, text: VaultMessages.walletDemoMessage)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: Controleren

    private var checkingPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(VaultMessages.walletCheckingIntro)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.bottom, 2)
                ForEach(Array(wallet.chosen.enumerated()), id: \.element.id) { index, credential in
                    VaultWalletCard(credential: credential, mode: .checking(done: wallet.checksDone(credential)))
                        .opacity(index < shownChecking ? 1 : 0)
                        .offset(y: index < shownChecking ? 0 : 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task {
            shownChecking = 0
            for index in wallet.chosen.indices {
                if reduceMotion {
                    shownChecking = wallet.chosen.count
                    break
                }
                withAnimation(.spring(duration: 0.45, bounce: 0.2)) { shownChecking = index + 1 }
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    // MARK: Knoppen

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 8) {
            switch wallet.phase {
            case .choose:
                PaveSoftButton(title: "Terug", action: onBack)
                if wallet.state == .ready, !wallet.available.isEmpty {
                    PavePrimaryButton(title: wallet.selected.isEmpty ? VaultMessages.walletChooseFirst : VaultMessages.walletAdd(wallet.selected.count)) {
                        Task { await wallet.start() }
                    }
                    .disabled(wallet.selected.isEmpty)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: wallet.selected.count)
                }
            case .checking:
                PavePrimaryButton(title: VaultMessages.walletChecking, loadingTitle: VaultMessages.walletChecking, isLoading: true) {}
            case .done:
                PavePrimaryButton(title: VaultMessages.walletFinish, loadingTitle: VaultMessages.walletFinish, isLoading: wallet.isFinishing) {
                    Task { if await wallet.finish() { onDone() } }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, isShort ? 10 : 16)
    }
}
