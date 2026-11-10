import PAVECore
import SwiftUI

/// The task-consent picker designed for Ayla: which items and categories Ayla may use for one question.
/// Not shown yet; it needs the consent flow on the server (`vault_access_grants`) before it can do anything.
struct VaultAccessSelectionPanel: View {
    let items: [VaultItem]
    @Binding var selectedCategories: Set<String>
    @Binding var selectedItems: Set<String>
    let onContinue: () -> Void

    private var categories: [VaultSelectionList.Category] {
        [.init(id: "all", title: "Alle items", count: items.count)] + VaultCategory.allCases.map { category in
            .init(id: category.id, title: category.title, count: items.count { $0.category == category })
        }
    }

    private var selectionItems: [VaultSelectionList.Item] {
        items.map {
            .init(
                id: $0.id,
                title: $0.title,
                organisation: $0.place ?? "",
                period: $0.period ?? "",
                tint: $0.category.tint,
                category: $0.category.title
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.grabber)
                .frame(width: 52, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            ScrollView {
                VaultSelectionList(
                    categories: categories,
                    items: selectionItems,
                    selectedCategories: $selectedCategories,
                    selectedItems: $selectedItems
                )
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            VaultSelectionBar(count: selectedItems.count, onContinue: onContinue)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25, style: .continuous)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Ayla · toestemming kluis") {
    @Previewable @State var categories: Set<String> = []
    @Previewable @State var selected: Set<String> = ["propedeuse", "stageverslag"]
    ZStack(alignment: .bottom) {
        VStack(spacing: 16) {
            HStack {
                Image(.iconMenu)
                Spacer()
                PaveTitle("Ayla")
                Spacer()
                Image(.iconChat)
            }
            .padding(.horizontal, 24)
            Text("Ik zoek een nieuwe loopbaan, kun je me hiermee helpen?")
                .textStyle(.bodyMedium)
                .padding(14)
                .background(Color.surfaceTint, in: .rect(cornerRadius: 18))
                .frame(maxWidth: .infinity, alignment: .trailing)
                Text("Ik ga je helpen zoeken! Welke gegevens mag ik hiervoor gebruiken?")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.brandGreen)
                    .padding(14)
                    .background(Color.cardTintGreen, in: .rect(cornerRadius: 18))
                    .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)

        VaultAccessSelectionPanel(
            items: VaultContents.preview.items,
            selectedCategories: $categories,
            selectedItems: $selected,
            onContinue: {}
        )
        .frame(height: 590)
    }
    .ignoresSafeArea(edges: .bottom)
}
