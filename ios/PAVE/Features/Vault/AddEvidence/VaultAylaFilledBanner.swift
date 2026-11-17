import SwiftUI

/// Above the form Ayla filled in: check everything. When she saw more than one item, such as a certificate and a list of
/// grades, one item stays the default and adding them apart is one tap away.
struct VaultAylaFilledBanner: View {
    let splitTitles: [String]?
    let addsApart: Bool
    let onAddsApart: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AylaLetter()
                .paveIconFrame(36)
                .background(Color.paveAccent, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 6) {
                Text(VaultMessages.aylaFilledTitle)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.aylaFilledMessage)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if let splitTitles, let first = splitTitles.first {
                    split(splitTitles, first: first)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.paveDropZone, in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.paveFocusRing, lineWidth: 1) }
    }

    private func split(_ titles: [String], first: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VaultMessages.aylaSplitTitle(titles))
                .textStyle(.caption)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Picker(VaultMessages.aylaSplitTitle(titles), selection: Binding(get: { addsApart }, set: { apart in
                PaveHaptics.selection()
                withAnimation(.snappy(duration: 0.3)) { onAddsApart(apart) }
            })) {
                Text(VaultMessages.aylaSplitOne).tag(false)
                Text(VaultMessages.aylaSplitApart).tag(true)
            }
            .pickerStyle(.segmented)
            Text(VaultMessages.aylaSplitHint(apart: addsApart, first: first))
                .textStyle(.meta)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        VaultAylaFilledBanner(splitTitles: nil, addsApart: false) { _ in }
        VaultAylaFilledBanner(splitTitles: ["Scrum Master-certificaat", "Cijferlijst"], addsApart: false) { _ in }
    }
    .padding(24)
}
