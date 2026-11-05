import SwiftUI

struct PinScreen<Pad: View, Accessory: View>: View {
    var emblem: ImageResource?
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder let pad: (CGFloat) -> Pad
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        GeometryReader { proxy in
            switch PinScreenLayout(size: proxy.size) {
            case .compact:
                content(showsLogo: true)
                    .background { AuthTopAtmosphere() }
            case .wide:
                content(showsLogo: true)
                    .background { PaveCornerGradient() }
            case .split:
                HStack(spacing: 0) {
                    AuthBrandPanel()
                        .frame(width: proxy.size.width * 0.42)
                    content(showsLogo: false)
                        .background(Color.canvas.ignoresSafeArea())
                }
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func content(showsLogo: Bool) -> some View {
        ViewThatFits(in: .vertical) {
            column(.init(keySize: 96, emblem: true, message: true, footer: true, spacing: 32), showsLogo)
            column(.init(keySize: 84, emblem: true, message: true, footer: true, spacing: 28), showsLogo)
            column(.init(keySize: 76, emblem: true, message: true, footer: true, spacing: 24), showsLogo)
            column(.init(keySize: 68, emblem: false, message: true, footer: true, spacing: 24), showsLogo)
            column(.init(keySize: 60, emblem: false, message: false, footer: true, spacing: 20), showsLogo)
            column(.init(keySize: 52, emblem: false, message: false, footer: false, spacing: 16), showsLogo)
            column(.init(keySize: 46, emblem: false, message: false, footer: false, spacing: 12), showsLogo)
            ScrollView {
                column(.init(keySize: 52, emblem: false, message: false, footer: true, spacing: 16), showsLogo)
            }
        }
    }

    private func column(_ variant: Variant, _ showsLogo: Bool) -> some View {
        VStack(spacing: 0) {
            if showsLogo {
                AuthLogo()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
            }
            Spacer(minLength: showsLogo ? variant.spacing : 0)
            VStack(alignment: .leading, spacing: variant.spacing) {
                AuthIntro(
                    emblem: variant.emblem ? emblem : nil,
                    eyebrow: eyebrow,
                    title: title,
                    message: variant.message ? message : nil
                )
                .fixedSize(horizontal: false, vertical: true)
                pad(variant.keySize)
                    .frame(maxWidth: .infinity)
                accessory()
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
            if variant.footer {
                AuthFooter()
            }
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
    }

    private struct Variant {
        let keySize: CGFloat
        let emblem: Bool
        let message: Bool
        let footer: Bool
        let spacing: CGFloat
    }
}

private enum PinScreenLayout {
    case compact
    case wide
    case split

    init(size: CGSize) {
        if size.width >= 1000 && size.width > size.height {
            self = .split
        } else if size.width >= 600 {
            self = .wide
        } else {
            self = .compact
        }
    }
}

struct PinErrorSlot: View {
    let message: String?

    var body: some View {
        Group {
            if let message {
                PaveInlineError(message: message)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
    }
}
