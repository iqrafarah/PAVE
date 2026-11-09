import PAVECore
import SwiftUI

/// The glass text field at the bottom: plus (add something to the message), Ayla's mark, the text,
/// microphone (dictation) and send. With an empty field, send becomes the button to talk with Ayla
/// (voice mode), as in ChatGPT and Claude. Added files show above the text.
struct AylaComposer: View {
    @Binding var text: String
    var attachments: [AylaAttachment] = []
    var isEnabled = true
    /// Offline you can keep typing, but sending waits until there is a connection again.
    var isOnline = true
    /// Ayla is thinking or writing: the send button becomes a stop button, as in ChatGPT.
    var isAnswering = false
    var onStop: (() -> Void)?
    var isListening = false
    var placeholderColor = Color.inkMuted.opacity(0.41)
    /// Over the white panel the field is almost white (Figma), elsewhere it is clear glass.
    var isOverPanel = false
    var isFocused: FocusState<Bool>.Binding
    let onAdd: () -> Void
    var onRemoveAttachment: (AylaAttachment) -> Void = { _ in }
    let onMicrophone: () -> Void
    let onSend: () -> Void
    /// Starts a spoken conversation. Nil when voice is not available.
    var onVoice: (() -> Void)?
    /// Where the voice button is on screen, so the conversation's intro can come out of it.
    var onVoiceButtonFrame: ((CGRect) -> Void)?
    /// Lets the field shrink into the voice bar's field when a spoken conversation starts, and grow back.
    var morph: Namespace.ID?

    /// The round buttons are 30 pt; their hit area is 38 wide and 53 high, with the circle where Figma has it.
    static let roundButtonWidth: CGFloat = 38

    private var canSend: Bool {
        isEnabled && isOnline && !isAnswering && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsVoiceButton: Bool {
        onVoice != nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { file in
                            AylaAttachmentChip(name: file.name) { onRemoveAttachment(file) }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 10)
            }
            field
        }
        .glassEffect(isOverPanel ? .regular.tint(.white.opacity(0.8)) : .clear, in: .rect(cornerRadius: 25))
        .matchedFrame("field", in: morph)
    }

    private var field: some View {
        HStack(spacing: 0) {
            Button(action: onAdd) {
                Image(.iconPlus)
                    .frame(width: 44, height: 53)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .disabled(!isEnabled)
            .accessibilityLabel("Toevoegen aan je bericht")

            PaveMark()
                .padding(.leading, 1.5)
                .padding(.trailing, 9.4)

            TextField("Vraag het aan Ayla", text: $text, prompt: Text("Vraag het aan Ayla").foregroundStyle(placeholderColor), axis: .vertical)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .tint(.brandGreen)
                .lineLimit(1...5)
                .submitLabel(.send)
                .focused(isFocused)
                .onSubmit(send)
                .disabled(!isEnabled)
                .padding(.vertical, 16)

            Button(action: onMicrophone) {
                Image(.iconMicrophone)
                    .renderingMode(.template)
                    .foregroundStyle(isListening ? Color.brandGreen : .ink)
                    .frame(width: 31, height: 53)
                    .padding(.leading, 13)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .disabled(!isEnabled)
            .accessibilityLabel(isListening ? "Stop met inspreken" : "Inspreken")

            if isAnswering, let onStop {
                Button(action: onStop) {
                    Image(.iconStop)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .foregroundStyle(Color.white)
                        .frame(width: 30, height: 30)
                        .background(Color.brandGreen, in: .circle)
                        .shadow(color: .black.opacity(0.25), radius: 2)
                        .frame(width: Self.roundButtonWidth, height: 53)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("Stop Ayla")
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if showsVoiceButton, let onVoice {
                Button(action: onVoice) {
                    PixelWaveIcon()
                        .frame(width: 30, height: 30)
                        .background(Color.brandGreen, in: .circle)
                        .shadow(color: .black.opacity(0.25), radius: 2)
                        .frame(width: Self.roundButtonWidth, height: 53)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .disabled(!isEnabled || !isOnline)
                .opacity(isOnline ? 1 : 0.4)
                .accessibilityLabel("Praat met Ayla")
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onVoiceButtonFrame?($0) }
            } else {
                Button(action: send) {
                    Image(.iconSend)
                        .frame(width: 30, height: 30)
                        .background(Color.brandGreen, in: .circle)
                        .shadow(color: .black.opacity(0.25), radius: 2)
                        .frame(width: Self.roundButtonWidth, height: 53)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .disabled(!isOnline)
                .opacity(isOnline ? 1 : 0.4)
                .accessibilityLabel("Versturen")
                .accessibilityHint(isOnline ? "" : "Je bent offline")
            }
        }
        .padding(.leading, 4.5)
        .padding(.trailing, 7)
        .frame(minHeight: 53)
        // Tapping anywhere in the field, also next to the text or on Ayla's mark, puts the cursor in it.
        .contentShape(.rect)
        .onTapGesture { if isEnabled { isFocused.wrappedValue = true } }
    }

    private func send() {
        guard canSend else { return }
        onSend()
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    VStack(spacing: 24) {
        AylaComposer(text: $text, isFocused: $focused, onAdd: {}, onMicrophone: {}, onSend: {}, onVoice: {})
        AylaComposer(text: $text, attachments: [AylaAttachment(name: "cv.pdf", text: "Stage")!], isFocused: $focused, onAdd: {}, onMicrophone: {}, onSend: {})
    }
        .padding(.leading, 33)
        .padding(.trailing, 31)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.canvas)
}
