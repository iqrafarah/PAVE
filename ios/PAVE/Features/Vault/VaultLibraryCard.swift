import PAVECore
import SwiftUI

/// An item in the vault, as a tile in the grid or a row in the list, like the cards in the design.
struct VaultLibraryCard: View {
    let item: VaultItem
    let isGrid: Bool
    @Environment(VaultModel.self) private var model: VaultModel?
    @State private var look: VaultLogoLook?

    private var logo: VaultItem.File? { model?.logo(of: item) }
    private var cover: VaultItem.File? { model?.cover(of: item) }

    var body: some View {
        Group {
            if isGrid { gridCard } else { listCard }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .clipShape(.rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .task(id: logo?.id) {
            guard let logo else { look = nil; return }
            let loaded = await model?.look(of: logo)
            withAnimation(.easeOut(duration: 0.25)) { look = loaded }
        }
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The band shows the cover, or else a light tint of the strongest colour in the logo; the logo is the avatar.
            (look?.tint ?? item.category.tint)
                .overlay {
                    if let cover {
                        VaultThumbnail(source: .file(cover), cornerRadius: 0)
                    }
                }
                .frame(height: 48)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    VaultLogoAvatar(look: look, name: item.organisationName ?? item.title, size: 44)
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
        HStack(alignment: .top, spacing: 12) {
            VaultLogoAvatar(look: look, name: item.organisationName ?? item.title, size: 48)
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
        .padding(12)
    }

    @ViewBuilder
    private func details(lineLimit: Int) -> some View {
        if let place = item.place {
            PaveIconLabel(icon: .iconBuildingOfficeSolid, text: place)
                .lineLimit(lineLimit)
        }
        if let period = item.period {
            PaveIconLabel(icon: .iconCalendarDaysSolid, text: period)
                .lineLimit(1)
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
