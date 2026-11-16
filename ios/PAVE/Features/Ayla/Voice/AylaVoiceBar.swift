import SwiftUI

/// The bottom bar during a spoken conversation, laid out like ChatGPT's: a glass text field with the plus (you can
/// also type, and Ayla answers out loud), a round button to mute the microphone, and a round button to stop.
struct AylaVoiceBar: View {
    @Binding var text: String
    let isMuted: Bool
    var isFocused: FocusState<Bool>.Binding
    let onAdd: () -> Void
    let onSend: () -> Void
    let onMute: () -> Void
    let onStop: () -> Void
    /// Lets the text field shrink into this bar's field; the round buttons then slide out of it.
    var morph: Namespace.ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsButtons = false

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            HStack(spacing: 0) {
                Button(action: onAdd) {
                    Image(.iconPlus)
                        .frame(width: 44, height: 53)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("Toevoegen aan je bericht")

                TextField("Vraag het aan Ayla", text: $text, prompt: Text("Vraag het aan Ayla").foregroundStyle(Color.inkMuted.opacity(0.6)), axis: .vertical)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .tint(.paveAccent)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .focused(isFocused)
                    .onSubmit(send)
                    .onChange(of: text) { old, new in
                        guard new.hasSuffix("\n"), !old.hasSuffix("\n") else { return }
                        text = String(new.dropLast())
                        send()
                    }
                    .padding(.vertical, 16)

                if canSend {
                    Button(action: send) {
                        Image(.iconSend)
                            .paveIconFrame(30)
                            .background(Color.paveAccent, in: .circle)
                            .frame(width: AylaComposer.roundButtonWidth, height: 53)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pave)
                    .accessibilityLabel("Versturen")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.leading, 4.5)
            .padding(.trailing, canSend ? 7 : 16)
            .frame(minHeight: 53)
            .contentShape(.rect)
            .onTapGesture { isFocused.wrappedValue = true }
            .glassEffect(.clear, in: .rect(cornerRadius: 26.5))
            .matchedFrame("field", in: morph)

            Button(action: onMute) {
                Image(.iconMicrophone)
                    .renderingMode(.template)
                    .foregroundStyle(isMuted ? Color.inkMuted : .ink)
                    .overlay {
                        if isMuted {
                            Capsule()
                                .fill(Color.criticalInk)
                                .frame(width: 2.5, height: 26)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                    .frame(width: 53, height: 53)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .glassEffect(.clear.interactive(), in: .circle)
            .modifier(SlideOut(isShown: showsButtons))
            .accessibilityLabel(isMuted ? "Microfoon aanzetten" : "Microfoon uitzetten")

            Button(action: onStop) {
                Image(.iconPlus)
                    .renderingMode(.template)
                    .resizable()
                    .paveIconFrame(15)
                    .rotationEffect(.degrees(45))
                    .foregroundStyle(Color.white)
                    .paveIconFrame(53)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .glassEffect(.regular.tint(.paveAccent).interactive(), in: .circle)
            .modifier(SlideOut(isShown: showsButtons))
            .accessibilityLabel("Gesprek stoppen")
        }
        .animation(.spring(duration: 0.3), value: canSend)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.3).delay(0.1)) {
                showsButtons = true
            }
        }
    }

    private func send() {
        guard canSend else { return }
        onSend()
    }
}

/// The round buttons come out of the text field: from small and tucked against it to their place.
private struct SlideOut: ViewModifier {
    let isShown: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isShown ? 1 : 0.4)
            .offset(x: isShown ? 0 : -36)
            .opacity(isShown ? 1 : 0)
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    VStack(spacing: 20) {
        AylaVoiceBar(text: $text, isMuted: false, isFocused: $focused, onAdd: {}, onSend: {}, onMute: {}, onStop: {})
        AylaVoiceBar(text: .constant("Welke banen passen bij mij?"), isMuted: true, isFocused: $focused, onAdd: {}, onSend: {}, onMute: {}, onStop: {})
    }
    .padding(.horizontal, 24)
    .background(Color.canvas)
}
