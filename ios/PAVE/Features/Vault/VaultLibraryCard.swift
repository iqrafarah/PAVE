import PAVECore
import SwiftUI

/// An item in the vault, as a tile in the grid or a row in the list, like the cards in the design. The circle shows the
/// logo, in both views. The grid has the cover in its band; the list has no band and fades the colour of the logo from the
/// top left instead (Figma 1348:9). Without a logo the cover gives the colour; without either, the category.
struct VaultLibraryCard: View {
    let item: VaultItem
    let isGrid: Bool
    @Environment(VaultModel.self) private var model: VaultModel?
    @State private var logoLook: VaultLogoLook?
    @State private var coverLook: VaultLogoLook?

    private var logo: VaultItem.File? { model?.logo(of: item) }
    private var cover: VaultItem.File? { model?.cover(of: item) }
    /// Behind the cover in the band of the grid.
    private var bandTint: Color { logoLook?.tint ?? item.category.tint }
    private var fadeTint: Color { logoLook?.tint ?? coverLook?.tint ?? item.category.tint }

    var body: some View {
        Group {
            if isGrid { gridCard } else { listCard }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if isGrid {
                Color.white
            } else {
                // The fade from the top left corner in the list, as in Figma 1348:9; a cover photo shows only in the grid.
                LinearGradient(
                    stops: [.init(color: fadeTint, location: 0), .init(color: .white, location: 0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .task(id: logo?.id) {
            guard let logo else { logoLook = nil; return }
            let loaded = await model?.look(of: logo)
            withAnimation(.easeOut(duration: 0.25)) { logoLook = loaded }
        }
        .task(id: isGrid || logo != nil ? nil : cover?.id) {
            guard !isGrid, logo == nil, let cover else { coverLook = nil; return }
            let loaded = await model?.look(of: cover)
            withAnimation(.easeOut(duration: 0.25)) { coverLook = loaded }
        }
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The band shows the cover, or else a light tint of the strongest colour in the logo; the logo is the avatar.
            bandTint
                .overlay {
                    if let cover {
                        VaultThumbnail(source: .file(cover), cornerRadius: 0)
                    }
                }
                .frame(height: 48)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    VaultLogoAvatar(look: logoLook, name: item.organisationName ?? item.title, size: 44)
                        .padding(.leading, 12)
                        .offset(y: 22)
                }
                .overlay(alignment: .topTrailing) {
                    VaultStatusBadge(status: item.status)
                        .padding(8)
                }
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                details(lineLimit: 2)
                if !item.skills.isEmpty {
                    skills(limit: 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 30)
            .padding(.bottom, 12)
        }
    }

    private var listCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VaultLogoAvatar(look: logoLook, name: item.organisationName ?? item.title, size: 64)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .textStyle(.bubble)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    VaultStatusBadge(status: item.status)
                }
                details(lineLimit: 1)
                if !item.skills.isEmpty {
                    skills(limit: 2)
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func details(lineLimit: Int) -> some View {
        if let place = item.place {
            PaveIconLabel(icon: .iconVaultBuildingOutline, text: place)
                .lineLimit(lineLimit)
        }
        if let period = item.period {
            // "mrt 2025 - dec 2025" fits a narrow tile (iPhone Duo) by getting a little smaller instead of being cut off.
            PaveIconLabel(icon: .iconVaultCalendarOutline, text: period)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func skills(limit: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(item.skills.prefix(limit), id: \.self) { skill in
                VaultSkillChip(text: skill)
            }
            if item.skills.count > limit {
                VaultSkillChip(text: "+\(item.skills.count - limit)")
                    .accessibilityLabel("en nog \(item.skills.count - limit)")
            }
        }
    }
}

#Preview("Raster") {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
        ForEach(VaultContents.preview.items) { VaultLibraryCard(item: $0, isGrid: true) }
    }
    .padding()
    .background(Color.canvas)
}

#Preview("Lijst") {
    VStack(spacing: 12) {
        ForEach(VaultContents.preview.items) { VaultLibraryCard(item: $0, isGrid: false) }
    }
    .padding()
    .background(Color.canvas)
}
