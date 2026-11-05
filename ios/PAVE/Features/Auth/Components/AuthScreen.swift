import SwiftUI

struct AuthScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            switch AuthLayout(size: proxy.size) {
            case .compact:
                compactLayout(minHeight: proxy.size.height)
            case .card:
                cardLayout(minHeight: proxy.size.height)
            case .split:
                splitLayout(size: proxy.size)
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func compactLayout(minHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                AuthLogo()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                content
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
                    content
                }
                .padding(40)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.white, in: .rect(cornerRadius: 28))
                .shadow(color: Color.brandGreen.opacity(0.08), radius: 32, y: 12)
                .padding(.horizontal, 32)
                Spacer(minLength: 24)
                AuthFooter()
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
        }
        .authScrollBehavior()
        .background { PaveCornerGradient() }
    }

    private func splitLayout(size: CGSize) -> some View {
        HStack(spacing: 0) {
            AuthBrandPanel()
                .frame(width: size.width * 0.42)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 48)
                    content
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 48)
                    Spacer(minLength: 24)
                    AuthFooter(showsTagline: false)
                }
                .frame(maxWidth: .infinity, minHeight: size.height)
            }
            .authScrollBehavior()
            .background(Color.canvas.ignoresSafeArea())
        }
    }
}

private enum AuthLayout {
    case compact
    case card
    case split

    init(size: CGSize) {
        if size.width >= 1000 && size.width > size.height {
            self = .split
        } else if size.width >= 600 {
            self = .card
        } else {
            self = .compact
        }
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
    var showsTagline = true

    var body: some View {
        VStack(spacing: 6) {
            Text("Hulp nodig? Neem contact op met de IT-support van je organisatie.")
                .textStyle(.footnote)
                .multilineTextAlignment(.center)
            if showsTagline {
                Text("Jouw ontwikkeling. Jouw mogelijkheden.")
                    .textStyle(.caption)
            }
        }
        .foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
    }
}

struct AuthBrandPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            AuthLogo(width: 220)
            Text("Jouw ontwikkeling.\nJouw mogelijkheden.")
                .textStyle(.title)
                .foregroundStyle(Color.brandGreen)
        }
        .padding(56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { PaveCornerGradient() }
    }
}

struct AuthTopAtmosphere: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color.canvas
            LinearGradient(
                stops: [
                    .init(color: .brandGreen, location: 0),
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
                .init(color: .brandGreen, location: 0),
                .init(color: .canvas, location: 0.25),
                .init(color: .canvas, location: 0.74),
                .init(color: .brandGreen, location: 1),
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
        Text("Inhoud")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
