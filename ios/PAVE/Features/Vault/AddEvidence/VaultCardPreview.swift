import PAVECore
import SwiftUI

/// The top of the card as it will look in the vault, live while you choose: the band shows your cover, or else the
/// strongest colour of your logo; the logo sits in the round avatar; the title below.
struct VaultCardPreview: View {
    let look: VaultLogoLook?
    let cover: VaultThumbnail.Source?
    let title: String
    let category: VaultCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            (look?.tint ?? category.tint)
                .overlay {
                    if let cover {
                        VaultThumbnail(source: cover, cornerRadius: 0)
                            .transition(.opacity)
                    }
                }
                .frame(height: 64)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    VaultLogoAvatar(look: look, name: title.isEmpty ? category.singularTitle : title, size: 60)
                        .padding(.leading, 16)
                        .offset(y: 30)
                }
            Text(title.isEmpty ? category.singularTitle : title)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .clipShape(.rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .animation(.easeOut(duration: 0.3), value: look)
        .animation(.easeOut(duration: 0.3), value: cover)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zo ziet je kaart eruit")
    }
}
