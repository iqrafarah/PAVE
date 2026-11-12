import SwiftUI

/// "Ayla mag dit document bekijken en gebruiken": a calm card with a switch instead of a loose checkbox. It starts off,
/// says what it means (Ayla takes the evidence along in questions and searches) and that you can take it back.
struct VaultAylaConsentCard: View {
    @Binding var isOn: Bool
    let hasFile: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AylaLetter()
                .frame(width: 36, height: 36)
                .background(Color.paveAccent, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 4) {
                Text(VaultMessages.aylaConsent(hasFile: hasFile))
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(VaultMessages.aylaConsentMeaning)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn.animation(.snappy(duration: 0.25)))
                .labelsHidden()
                .tint(.paveAccent)
        }
        .padding(14)
        .background(isOn ? Color.paveDropZone : Color.white, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isOn ? Color.paveFocusRing : Color.railBorder, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 12))
        .onTapGesture {
            PaveHaptics.selection()
            withAnimation(.snappy(duration: 0.25)) { isOn.toggle() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VaultMessages.aylaConsent(hasFile: hasFile))
        .accessibilityHint(VaultMessages.aylaConsentMeaning)
        .accessibilityValue(isOn ? "Aan" : "Uit")
        .accessibilityAddTraits(.isToggle)
        .accessibilityAction { isOn.toggle() }
    }
}

#Preview {
    @Previewable @State var isOn = false
    VaultAylaConsentCard(isOn: $isOn, hasFile: true)
        .padding(24)
}
