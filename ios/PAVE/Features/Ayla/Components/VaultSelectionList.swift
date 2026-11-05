import SwiftUI

/// The content of the panel in which the user chooses what Ayla may use (Figma frame "Kluis toestemming").
/// It is ready for the vault; there is no vault in the database yet, so the app does not show it.
struct VaultSelectionList: View {
    struct Category: Identifiable {
        let id: String
        let title: String
        let count: Int
    }

    struct Item: Identifiable {
        let id: String
        let title: String
        let organisation: String
        let period: String
        let tint: Color
    }

    let categories: [Category]
    let items: [Item]
    @Binding var selectedCategories: Set<String>
    @Binding var selectedItems: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    ForEach(categories) { category in
                        VaultCategoryTile(title: category.title, count: category.count, isOn: selectedCategories.contains(category.id)) {
                            toggle(category.id, in: &selectedCategories)
                        }
                    }
                }
                .padding(.leading, 6)
                .padding(.trailing, 26)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -26)
            .padding(.leading, 26)

            VStack(spacing: 13) {
                ForEach(items) { item in
                    VaultItemCard(
                        title: item.title,
                        organisation: item.organisation,
                        period: item.period,
                        tint: item.tint,
                        isSelected: selectedItems.contains(item.id)
                    ) {
                        toggle(item.id, in: &selectedItems)
                    }
                }
            }
            .padding(.leading, -1)
            .padding(.trailing, -1)
        }
    }

    private func toggle(_ id: String, in set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }
}

#Preview {
    @Previewable @State var categories: Set<String> = []
    @Previewable @State var items: Set<String> = ["a", "c"]
    ScrollView {
        VaultSelectionList(
            categories: [
                .init(id: "all", title: "Alle items", count: 3),
                .init(id: "diplomas", title: "Diploma's", count: 1),
                .init(id: "certificates", title: "Certificaten", count: 0),
                .init(id: "projects", title: "Projecten", count: 2),
            ],
            items: [
                .init(id: "a", title: "Diploma", organisation: "Voorbeeldschool", period: "2020 - 2025", tint: .cardTintApricot),
                .init(id: "b", title: "Bijbaan", organisation: "Voorbeeldwinkel", period: "Nov 2025 - nu", tint: .cardTintGreen),
                .init(id: "c", title: "Eindverslag stage", organisation: "Voorbeeldbureau", period: "Mar 2025 - Dec 2025", tint: .cardTintLime),
            ],
            selectedCategories: $categories,
            selectedItems: $items
        )
        .padding(.leading, 26)
        .padding(.trailing, 25)
    }
}
