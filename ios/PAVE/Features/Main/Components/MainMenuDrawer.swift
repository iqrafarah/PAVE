import SwiftUI

/// The menu where there is no room for a sidebar (iPhone, the open iPhone Duo held upright, the outer display of
/// iPhone Duo): a plain panel against the left edge, from top to bottom, that slides over the dimmed screen, laid out
/// like ChatGPT and the same as the sidebar on iPad. Tap next to it or swipe it away to close it.
/// On the outer display of iPhone Duo the menu button sits in the bar along the side. There, as in ChatGPT, it turns
/// into a close button, the chat button below it into a new conversation, and your account and the bell go to the
/// bottom of that bar.
struct MainMenuDrawer: View {
    @Binding var isPresented: Bool
    let selection: MainDestination
    let name: String?
    /// Where the menu button is on screen; zero while unknown.
    let menuButtonFrame: CGRect
    let onSelect: (MainDestination) -> Void
    let onNewConversation: () -> Void
    let onSignOut: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0

    private static let inset: CGFloat = 16
    static let width: CGFloat = 300
    private static let buttonSize: CGFloat = 44

    /// The menu button is in the bar along the side, next to the panel, not under it.
    static func isButtonBeside(_ frame: CGRect) -> Bool {
        !frame.isEmpty && frame.minX > width
    }

    var body: some View {
        // Measured inside the safe area, so the insets are known; drawn over the whole screen.
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let safeOrigin = proxy.frame(in: .global).origin
            let origin = CGPoint(x: safeOrigin.x - insets.leading, y: safeOrigin.y - insets.top)
            let screen = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            let isBeside = Self.isButtonBeside(menuButtonFrame)
            let menuButton = menuButtonFrame.offsetBy(dx: -origin.x, dy: -origin.y)

            ZStack(alignment: .topLeading) {
                if isPresented {
                    Color.black.opacity(0.18)
                        .contentShape(.rect)
                        .onTapGesture(perform: close)
                        .accessibilityLabel("Menu sluiten")
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity)

                    panel(insets: insets, isBeside: isBeside, menuButton: menuButtonFrame.isEmpty ? nil : menuButton)
                        .frame(maxHeight: .infinity)
                        .offset(x: min(0, drag))
                        .gesture(swipeToClose)
                        .transition(reduceMotion ? .opacity : .move(edge: .leading))

                    if isBeside {
                        sideButtons(menuButton: menuButton, size: screen, insets: insets)
                            .transition(.opacity)
                    }
                }
            }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            .offset(x: -insets.leading, y: -insets.top)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.12), value: isPresented)
        .accessibilityAction(.escape, close)
    }

    /// The content starts at the top, right under the status bar (in line with the menu button when that is at the
    /// top); the buttons sit at the bottom, as far from the bottom edge as from the side, so they follow the rounded
    /// corner of the screen.
    private func panel(insets: EdgeInsets, isBeside: Bool, menuButton: CGRect?) -> some View {
        let underStatusBar = insets.top + 6
        let inLineWithButton = isBeside ? nil : menuButton.map { max(8, $0.midY - 22) }
        let top = min(underStatusBar, inLineWithButton ?? underStatusBar)
        return
        MainSidebar(
            style: isBeside ? .beside : .drawer,
            selection: selection,
            name: name,
            onSelect: { destination in
                onSelect(destination)
                close()
            },
            onNewConversation: {
                onNewConversation()
                close()
            },
            onSignOut: onSignOut,
            onClose: close
        )
        // The content stays clear of the status bar, the home indicator and the rounded screen corners.
        .padding(.leading, Self.inset + insets.leading)
        .padding(.trailing, Self.inset)
        .padding(.top, top)
        .padding(.bottom, max(Self.inset, insets.bottom - 18))
        .frame(width: Self.width + insets.leading, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            Color.canvas
                .overlay(alignment: .trailing) {
                    Color.railBorder.frame(width: 1)
                }
        }
        .accessibilityAddTraits(.isModal)
    }

    /// The bar along the side of the outer display of iPhone Duo, while the menu is open.
    private func sideButtons(menuButton: CGRect, size: CGSize, insets: EdgeInsets) -> some View {
        ZStack(alignment: .topLeading) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Menu sluiten")
            .position(x: menuButton.midX, y: menuButton.midY)

            // Under the close button, where the chat button was; that one and the menu button hide while the menu is
            // open, so no second glass circle shows underneath.
            Button {
                onNewConversation()
                close()
            } label: {
                Image(.iconCompose)
                    .renderingMode(.template)
                    .foregroundStyle(Color.white)
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
                    .background(Color.brandGreen, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Nieuw gesprek")
            .position(x: menuButton.midX, y: menuButton.midY + Self.buttonSize + 16)

            MainAccountCapsule(
                axis: .vertical,
                name: name,
                selection: selection,
                onSelect: { destination in
                    onSelect(destination)
                    close()
                },
                onSignOut: onSignOut
            )
            .fixedSize()
            .position(x: menuButton.midX, y: size.height - max(16, insets.bottom) - 50)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var swipeToClose: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($drag) { value, state, _ in state = value.translation.width }
            .onEnded { value in
                if value.translation.width < -60 || value.predictedEndTranslation.width < -160 { close() }
            }
    }

    private func close() {
        isPresented = false
    }
}

#Preview {
    @Previewable @State var isPresented = true
    ZStack {
        Color.canvas.ignoresSafeArea()
        Button("Menu") { isPresented = true }
        MainMenuDrawer(
            isPresented: $isPresented,
            selection: .ayla,
            name: "Daaf",
            menuButtonFrame: .zero,
            onSelect: { _ in },
            onNewConversation: {},
            onSignOut: {}
        )
    }
}
