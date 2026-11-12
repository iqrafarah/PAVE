import PAVECore
import SwiftUI

struct AuthScreen<Intro: View, Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var stableSize: CGSize = .zero

    private let intro: Intro
    private let content: Content

    init(@ViewBuilder intro: () -> Intro, @ViewBuilder content: () -> Content) {
        self.intro = intro()
        self.content = content()
    }

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
                compactLayout(minHeight: proxy.size.height)
            case .card:
                cardLayout(minHeight: proxy.size.height)
            case .split(let split):
                splitLayout(split)
            }
        }
        .trackingStableSize($stableSize)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 24) {
            intro
            content
        }
    }

    private func compactLayout(minHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                AuthLogo()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                stacked
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                Spacer(minLength: 0)
                AuthFooter()
            }
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity, minHeight: minHeight)
        }
        .authScrollBehavior()
        .background { AuthTopAtmosphere() }
    }

    private func cardLayout(minHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 48)
                VStack(alignment: .leading, spacing: 32) {
                    AuthLogo()
                    stacked
                }
                .padding(40)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.white, in: .rect(cornerRadius: 28))
                .shadow(color: Color.paveAccent.opacity(0.08), radius: 32, y: 12)
                .padding(.horizontal, 32)
                Spacer(minLength: 24)
                AuthFooter()
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
        }
        .authScrollBehavior()
        .background { PaveCornerGradient() }
    }

    private func splitLayout(_ split: FoldSplit) -> some View {
        SplitPanes(split: split) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AuthLogo()
                        .padding(.top, 8)
                    Spacer(minLength: 24)
                    intro
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 24)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: split.first.height, alignment: .leading)
            }
            .authScrollBehavior()
        } second: {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    content
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: split.second.height)
            }
            .authScrollBehavior()
        }
        .background { PaveCornerGradient() }
    }
}

struct AuthLogo: View {
    var width: CGFloat = 100

    var body: some View {
        Image(.paveLogo)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("PAVE")
    }
}

struct AuthFooter: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(SupportText.sentence("Hulp nodig? Neem contact op via "))
                .textStyle(.footnote)
                .multilineTextAlignment(.center)
            Text("Jouw voortgang. Jouw mogelijkheden.")
                .textStyle(.caption)
        }
        .foregroundStyle(Color.inkMuted)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
    }
}

struct AuthTopAtmosphere: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color.canvas
            LinearGradient(
                stops: [
                    .init(color: .paveAccent, location: 0),
                    .init(color: .canvas, location: 0.6),
                    .init(color: .canvas, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 130)
            .opacity(0.28)
        }
        .ignoresSafeArea()
    }
}

struct PaveCornerGradient: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .paveAccent, location: 0),
                .init(color: .canvas, location: 0.25),
                .init(color: .canvas, location: 0.74),
                .init(color: .paveAccent, location: 1),
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .opacity(0.5)
        .background(Color.canvas)
        .ignoresSafeArea()
    }
}

private extension View {
    func authScrollBehavior() -> some View {
        scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
    }
}

#Preview("iPhone") {
    AuthScreen {
        AuthIntro(eyebrow: "Inloggen", title: "Welkom bij PAVE")
    } content: {
        Text("Inhoud")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
