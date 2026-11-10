import PAVECore
import SwiftUI

/// Under Ayla's answer: what it leans on from what she remembers about you, as PAVE promises. Tap it to see the
/// notes themselves.
struct AylaUsedMemories: View {
    let notes: [AylaReply.UsedMemory]
    let onShowMemory: () -> Void

    @State private var isShowing = false

    private var categories: [AylaMemory.Category] {
        AylaMemory.Category.allCases.filter { category in notes.contains { $0.category == category } }
    }

    var body: some View {
        Button {
            PaveHaptics.tap(.light)
            isShowing = true
        } label: {
            HStack(spacing: 6) {
                PaveMark(size: 3)
                Text("Gebaseerd op: \(categories.map { $0.title.lowercased() }.joined(separator: ", "))")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .padding(.leading, 4)
            .frame(minHeight: 28)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityLabel("Gebaseerd op wat Ayla over je weet: \(categories.map(\.title).joined(separator: ", "))")
        .accessibilityHint("Toont welke dingen")
        .popover(isPresented: $isShowing) {
            details
                .presentationCompactAdaptation(.popover)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dit antwoord steunt op")
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            ForEach(notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 10) {
                    Image(note.category.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .foregroundStyle(Color.brandGreen)
                        .frame(width: 24, height: 24)
                        .background(note.category.tint, in: .rect(cornerRadius: 7))
                        .accessibilityHidden(true)
                    Text(note.text)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                isShowing = false
                onShowMemory()
            } label: {
                Text("Bekijk wat Ayla over je weet")
                    .textStyle(.label)
                    .foregroundStyle(Color.brandGreen)
                    .frame(minHeight: 36)
            }
            .buttonStyle(.pave)
        }
        .padding(16)
        .frame(width: 290, alignment: .leading)
    }
}

#Preview {
    AylaUsedMemories(notes: [
        .init(text: "Je studeert ICT aan Fontys.", category: .education),
        .init(text: "Je werkt als leidinggevende bij de Plus.", category: .work),
    ]) {}
    .padding()
    .background(Color.canvas)
}
