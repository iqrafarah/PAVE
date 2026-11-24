import PAVECore
import SwiftUI

/// The second step: the chosen design large, and how to begin, with Ayla or yourself.
struct ApplicationStartView: View {
    let model: ApplicationStudioModel
    let photo: UIImage?
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(alignment: .top, spacing: 14) {
                    page(ApplicationPages(draft: model.draft, document: .cv, photo: photo))
                    page(ApplicationPages(draft: model.draft, document: .letter))
                }
                .frame(maxWidth: 520)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(ApplyMessages.howToBegin)
                        .textStyle(.emptyTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(ApplyMessages.chosenDesign(model.draft.template))
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { choices }
                    VStack(spacing: 12) { choices }
                }
                Button(ApplyMessages.otherDesign, action: onBack)
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var choices: some View {
        choice(
            title: ApplyMessages.aylaFills,
            text: ApplyMessages.aylaFillsHint(model.itemsForAyla.count),
            isPrimary: true,
            icon: { AylaLetter(color: .white).frame(width: 18, height: 18) }
        ) {
            Task { await model.begin(withAyla: true) }
        }
        .disabled(!model.canWrite)
        choice(
            title: ApplyMessages.fillYourself,
            text: ApplyMessages.fillYourselfHint,
            isPrimary: false,
            icon: {
                Image(.iconPencilSquareOutline)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.paveAccent)
            }
        ) {
            Task { await model.begin(withAyla: false) }
        }
    }

    private func choice(title: String, text: String, isPrimary: Bool, @ViewBuilder icon: () -> some View, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                icon()
                    .frame(width: 40, height: 40)
                    .background(isPrimary ? Color.paveAccentFill : Color.paveSurfaceTint, in: .circle)
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                Text(text)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .background(Color.panel, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isPrimary ? Color.paveAccent : Color.cardBorder, lineWidth: isPrimary ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.pave)
    }

    private func page(_ content: some View) -> some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / ApplicationPage.size.width
            content
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: ApplicationPage.size.width * scale, height: ApplicationPage.size.height * scale, alignment: .topLeading)
                .clipShape(.rect(cornerRadius: 4))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .aspectRatio(ApplicationPage.size.width / ApplicationPage.size.height, contentMode: .fit)
    }
}
