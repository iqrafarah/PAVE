import SwiftUI

/// A vault item in the library. It shows the verification outcome in both grid and list layouts.
struct VaultLibraryCard: View {
    let item: VaultItem
    let isSelected: Bool
    let isGrid: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isGrid { gridCard } else { listCard }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(.rect(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(isSelected ? Color.brandGreen : Color.cardBorder, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 17))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.categoryTint(for: item.category)
                .frame(height: 54)
                .overlay(alignment: .bottomLeading) {
                    VaultCompanyLogoView(logo: item.logo, organisation: item.organisation, size: 48)
                        .offset(x: 12, y: 22)
                }
                .overlay(alignment: .topTrailing) {
                    PaveCheckbox(isOn: isSelected, size: 18)
                        .padding(10)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
                statusBadge
                PaveIconLabel(icon: .iconBuilding, text: item.organisation)
                    .lineLimit(2)
                PaveIconLabel(icon: .iconCalendar, text: item.period)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.top, 29)
            .padding(.bottom, 13)
        }
    }

    private var listCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VaultCompanyLogoView(logo: item.logo, organisation: item.organisation, size: 58)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .textStyle(.bubble)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    statusBadge
                }
                Text(item.category.title)
                    .textStyle(.chip)
                    .foregroundStyle(Color.brandGreen)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.surfaceTint, in: .capsule)
                PaveIconLabel(icon: .iconBuilding, text: item.organisation)
                    .lineLimit(1)
                PaveIconLabel(icon: .iconCalendar, text: item.period)
                    .lineLimit(1)
            }
            PaveCheckbox(isOn: isSelected)
        }
        .padding(12)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: item.status.symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(item.status.title)
                .textStyle(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(item.status.foreground)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(item.status.background, in: .rect(cornerRadius: 6))
        .fixedSize()
    }
}

private extension Color {
    static func categoryTint(for category: VaultCategory) -> Color {
        switch category {
        case .diplomas: .cardTintApricot
        case .certificates, .badges, .projects, .feedback: .cardTintGreen
        case .all, .experiences, .internships, .skills, .reflections: .cardTintLavender
        }
    }
}

private extension VaultItemStatus {
    var title: String {
        switch self {
        case .verified: "Geverifieerd"
        case .toVerify: "Verifiëren"
        case .rejected: "Afgewezen"
        }
    }

    var symbol: String {
        switch self {
        case .verified: "checkmark.circle.fill"
        case .toVerify: "clock.fill"
        case .rejected: "exclamationmark.circle.fill"
        }
    }

    var foreground: Color {
        switch self {
        case .verified: .brandGreen
        case .toVerify: .orange
        case .rejected: .red
        }
    }

    var background: Color {
        switch self {
        case .verified: .cardTintGreen
        case .toVerify: .cardTintApricot
        case .rejected: .cardTintRose
        }
    }
}
