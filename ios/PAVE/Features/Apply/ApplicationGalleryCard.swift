import PAVECore
import SwiftUI

/// A design in the gallery, as Canva shows them: the CV filled with your own data, with its letter just behind it,
/// the name and what kind of design it is.
struct ApplicationGalleryCard: View {
    let draft: ApplicationDraft
    var photo: UIImage?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { proxy in
                    let scale = (proxy.size.width - 12) / ApplicationPage.size.width
                    ZStack(alignment: .topLeading) {
                        page(LetterPage(draft: draft), scale: scale)
                            .offset(x: 12, y: 0)
                            .opacity(0.9)
                        page(CVPage(draft: draft, photo: photo), scale: scale)
                            .offset(y: 10)
                    }
                }
                .aspectRatio(ApplicationPage.size.width / (ApplicationPage.size.height + 20), contentMode: .fit)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ApplyMessages.template(draft.template))
                        .textStyle(.label)
                        .foregroundStyle(isSelected ? Color.paveAccent : Color.ink)
                    Text(ApplicationTemplate.Style.allCases.filter(draft.template.styles.contains).map(ApplyMessages.style).joined(separator: ", "))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(Color.panel, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Color.paveAccent : Color.cardBorder, lineWidth: isSelected ? 2.5 : 1)
            }
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.pave)
        .accessibilityLabel(ApplyMessages.template(draft.template))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private func page(_ content: some View, scale: CGFloat) -> some View {
        content
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: ApplicationPage.size.width * scale, height: ApplicationPage.size.height * scale, alignment: .topLeading)
            .clipShape(.rect(cornerRadius: 4))
            .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }
}
