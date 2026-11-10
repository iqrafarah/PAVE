import PAVECore
import SwiftUI

/// A selectable vault item used in the library and Ayla's task-consent panel.
struct VaultItemCard: View {
    let title: String
    let organisation: String
    let period: String
    let tint: Color
    let isSelected: Bool
    var category: String?
    let action: () -> Void

    init(
        title: String,
        organisation: String,
        period: String,
        tint: Color,
        isSelected: Bool,
        category: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.organisation = organisation
        self.period = period
        self.tint = tint
        self.isSelected = isSelected
        self.category = category
        self.action = action
    }

    init(item: VaultItem, isSelected: Bool, action: @escaping () -> Void) {
        self.init(
            title: item.title,
            organisation: item.place ?? "",
            period: item.period ?? "",
            tint: item.category.tint,
            isSelected: isSelected,
            category: item.category.title,
            action: action
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                CompanyMonogram(name: organisation.isEmpty ? title : organisation, size: 58)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .textStyle(.bubble)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 11)
                    if let category {
                        Text(category)
                            .textStyle(.chip)
                            .foregroundStyle(Color.brandGreen)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.surfaceTint, in: .capsule)
                            .padding(.top, 5)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        PaveIconLabel(icon: .iconBuildingOfficeSolid, text: organisation)
                        PaveIconLabel(icon: .iconCalendarDaysSolid, text: period)
                    }
                    .padding(.leading, 5)
                    .padding(.top, 9)
                    .padding(.bottom, 11)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PaveCheckbox(isOn: isSelected)
                    .padding(.top, 12)
                    .padding(.trailing, 8)
            }
            .padding(.leading, 9)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .background {
                if isSelected {
                    FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.77, y: 1.67), end: UnitPoint(x: 0.23, y: -0.67))
                } else {
                    Color.white
                }
            }
            .clipShape(.rect(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 17))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: 13) {
        VaultItemCard(item: VaultContents.preview.items[0], isSelected: true) {}
        VaultItemCard(item: VaultContents.preview.items[1], isSelected: false) {}
    }
    .padding(.leading, 25)
    .padding(.trailing, 26)
}
