import PAVECore
import SwiftUI

struct PinScreen<Pad: View, Accessory: View>: View {
    var emblem: ImageResource?
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder let pad: (CGFloat) -> Pad
    @ViewBuilder let accessory: () -> Accessory

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var chromeHeight: CGFloat = 320
    @State private var stableSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let mode = AdaptiveMode.resolve(
                size: proxy.size,
                stableSize: stableSize == .zero ? proxy.size : stableSize,
                sizeClass: sizeClass,
                fold: proxy.foldSplit()
            )
            switch mode {
            case .compact:
                column(size: proxy.size)
                    .background { AuthTopAtmosphere() }
            case .card:
                column(size: proxy.size)
                    .background { PaveCornerGradient() }
            case .split(let split):
                panes(split)
                    .background { PaveCornerGradient() }
            }
        }
        .trackingStableSize($stableSize)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func column(size: CGSize) -> some View {
        let gap: CGFloat = size.height >= 700 ? 40 : 24
        let showsFooter = size.height >= 900
        let contentWidth = min(size.width, 560) - 64
        let reserved = 16 + gap + gap + 12 + 12
        let keySize = PinPadMetrics.keySize(
            fitting: CGSize(width: contentWidth, height: size.height - chromeHeight - reserved)
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AuthLogo()
                    .measuredChrome()
                    .padding(.top, 16)
                intro(showsEmblem: size.height >= 760, showsMessage: size.height >= 600)
                    .measuredChrome()
                    .padding(.top, gap)
                pad(keySize)
                    .frame(maxWidth: .infinity)
                    .padding(.top, gap)
                accessory()
                    .measuredChrome()
                    .padding(.top, 12)
                if showsFooter {
                    AuthFooter()
                        .measuredChrome()
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, minHeight: size.height, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(ChromeHeightKey.self) { chromeHeight = $0 }
    }

    private func panes(_ split: FoldSplit) -> some View {
        SplitPanes(split: split) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AuthLogo()
                        .padding(.top, 8)
                    Spacer(minLength: 24)
                    intro(showsEmblem: split.first.height >= 520, showsMessage: true)
                    accessory()
                        .padding(.top, 16)
                    Spacer(minLength: 24)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: split.first.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        } second: {
            let available = CGSize(width: split.second.width - 48, height: split.second.height - 48)
            let keySize = PinPadMetrics.keySize(fitting: available, maximum: PinPadMetrics.landscapeMaximumKeySize)
            ScrollView {
                pad(keySize)
                    .padding(24)
                    .frame(maxWidth: .infinity, minHeight: split.second.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func intro(showsEmblem: Bool, showsMessage: Bool) -> some View {
        AuthIntro(
            emblem: showsEmblem ? emblem : nil,
            eyebrow: eyebrow,
            title: title,
            message: showsMessage ? message : nil
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

enum PinPadMetrics {
    static let minimumKeySize: CGFloat = 44
    static let maximumKeySize: CGFloat = 104
    static let landscapeMaximumKeySize: CGFloat = 76
    static let dotsHeight: CGFloat = 14

    static func height(forKeySize key: CGFloat) -> CGFloat {
        dotsHeight + key * 0.4 + key * 4 + key * 0.2 * 3
    }

    static func width(forKeySize key: CGFloat) -> CGFloat {
        key * 3 + key * 0.26 * 2
    }

    static func keySize(fitting size: CGSize, maximum: CGFloat = maximumKeySize) -> CGFloat {
        let byWidth = size.width / width(forKeySize: 1)
        let byHeight = (size.height - dotsHeight) / (height(forKeySize: 1) - dotsHeight)
        return min(max(min(byWidth, byHeight), minimumKeySize), maximum).rounded(.down)
    }
}

private struct ChromeHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private extension View {
    func measuredChrome() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: ChromeHeightKey.self, value: proxy.size.height)
            }
        }
    }
}

enum PinMessages {
    static let tooEasy = "Te makkelijk te raden. Kies niet 6 keer hetzelfde cijfer en geen rij zoals 123456."
    static let differ = "De pincodes waren niet hetzelfde. Kies je pincode opnieuw."
    static let notSaved = "We konden je pincode niet opslaan. Probeer het opnieuw."

    static func incorrect(attemptsRemaining remaining: Int) -> String {
        remaining == 1 ? "Onjuiste pincode. Nog 1 poging." : "Onjuiste pincode. Nog \(remaining) pogingen."
    }

    static var all: [String] {
        [tooEasy, differ, notSaved] + (1...PinVault.maximumAttempts).map { incorrect(attemptsRemaining: $0) }
    }
}

struct PinErrorSlot: View {
    let message: String?

    var body: some View {
        MessageSlot(message: message, reserving: PinMessages.all) {
            PaveInlineError(message: $0)
        }
        .padding(.bottom, 8)
        .frame(minHeight: 44, alignment: .top)
    }
}
