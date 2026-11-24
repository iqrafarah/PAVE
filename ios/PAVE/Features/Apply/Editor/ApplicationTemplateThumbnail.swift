import PAVECore
import SwiftUI

/// A template as a small page with your own CV in it, the way Canva shows its designs filled in.
struct ApplicationTemplateThumbnail: View {
    let draft: ApplicationDraft
    let template: ApplicationTemplate
    var photo: UIImage?
    let isSelected: Bool
    let action: () -> Void

    private static let width: CGFloat = 104
    private var scale: CGFloat { Self.width / ApplicationPage.size.width }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ApplicationPagePreview(draft: shown, document: .cv, photo: photo)
                    .equatable()
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: Self.width, height: ApplicationPage.size.height * scale, alignment: .topLeading)
                    .clipShape(.rect(cornerRadius: 6))
                    .drawingGroup()
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? Color.paveAccent : Color.cardBorder, lineWidth: isSelected ? 2 : 1)
                    }
                    .background { RoundedRectangle(cornerRadius: 6).fill(.white).shadow(color: .black.opacity(0.06), radius: 4, y: 2) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Text(ApplyMessages.template(template))
                    .textStyle(.chip)
                    .foregroundStyle(isSelected ? Color.paveAccent : Color.ink)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(ApplyMessages.template(template))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var shown: ApplicationDraft {
        var copy = draft
        copy.template = template
        copy.palette = template.palette
        copy.showsPhoto = template.hasPhoto
        return copy
    }
}
