import SwiftUI

/// A real Apple Watch (Series 11, 42 mm, Sport Loop in Forest; Apple's product bezel for mock-ups) with `screen`
/// behind its glass. The screen of the image is transparent, so the bezel itself rounds the corners of the content.
struct WatchIllustration<Screen: View>: View {
    var width: CGFloat = 150
    @ViewBuilder let screen: Screen

    /// The image is 520 by 800 pixels with a 374 by 446 screen in the middle.
    private static var aspect: CGFloat { 800 / 520 }
    private static var screenWidth: CGFloat { 374 / 520 }
    private static var screenHeight: CGFloat { 446 / 800 }

    private var height: CGFloat { width * Self.aspect }

    var body: some View {
        ZStack {
            screen
                .frame(width: width * Self.screenWidth, height: height * Self.screenHeight)
            Image(.pairingWatch)
                .resizable()
                .interpolation(.high)
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

/// What the PAVE app on the Watch shows, built from the same parts and sizes as the Watch app (a 187 by 223 point
/// screen): first the request to connect, then Ayla's orb over the green glow, ready to listen.
struct WatchScreenPreview: View {
    enum Content: Equatable {
        case notConnected
        case connecting
        case ready
    }

    let content: Content
    private static let size = CGSize(width: 187, height: 223)

    var body: some View {
        GeometryReader { proxy in
            screen
                .frame(width: Self.size.width, height: Self.size.height)
                .scaleEffect(proxy.size.width / Self.size.width, anchor: .topLeading)
        }
        .clipped()
    }

    private var screen: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                stops: [.init(color: .black, location: content == .ready ? 0.4 : 0.55), .init(color: glow, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            HStack {
                Spacer()
                Text("9:41")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            switch content {
            case .notConnected:
                VStack(spacing: 6) {
                    Image(.iconDevicePhoneMobileSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.orbShade3)
                    Text(WatchConnectMessages.watchNotConnectedTitle)
                        .font(.system(size: 16, weight: .semibold))
                    Text(WatchConnectMessages.watchNotConnectedMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.top, 44)
                .transition(.opacity)
            case .connecting, .ready:
                VStack(spacing: 8) {
                    AylaPixelOrb(mode: content == .connecting ? .thinking : .idle)
                        .frame(width: 124, height: 124)
                    Text(content == .connecting ? " " : WatchConnectMessages.watchTapToTalk)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(.top, 38)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: content)
    }

    private var glow: Color {
        switch content {
        case .notConnected: .black
        case .connecting: .thinkingGlow
        case .ready: .brandGreen.opacity(0.7)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        WatchIllustration { WatchScreenPreview(content: .notConnected) }
        WatchIllustration { WatchScreenPreview(content: .ready) }
    }
    .padding()
    .background(Color.canvas)
}
