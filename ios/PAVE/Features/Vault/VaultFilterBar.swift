import PAVECore
import SwiftUI

/// One Filter button that opens Status, Bron and Sorteren, and the switch between grid and list.
struct VaultFilterBar: View {
    @Binding var filter: VaultFilter
    @Binding var isGrid: Bool

    private var activeCount: Int {
        (filter.status == nil ? 0 : 1) + (filter.origin == nil ? 0 : 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Picker(selection: $filter.status) {
                    Text("Alle statussen").tag(VaultItem.Status?.none)
                    ForEach(VaultItem.Status.allCases, id: \.self) { status in
                        Text(status.title).tag(Optional(status))
                    }
                } label: {
                    Text("Status")
                    Text(filter.status?.title ?? "Alle statussen")
                }
                .pickerStyle(.menu)
                Picker(selection: $filter.origin) {
                    Text("Alle bronnen").tag(VaultFilter.Origin?.none)
                    ForEach(VaultFilter.Origin.allCases, id: \.self) { origin in
                        Text(origin.title).tag(Optional(origin))
                    }
                } label: {
                    Text("Bron")
                    Text(filter.origin?.title ?? "Alle bronnen")
                }
                .pickerStyle(.menu)
                Picker(selection: $filter.order) {
                    ForEach(VaultFilter.Order.allCases, id: \.self) { order in
                        Text(order.title).tag(order)
                    }
                } label: {
                    Text("Datum")
                    Text(filter.order.title)
                }
                .pickerStyle(.menu)
                if filter.narrowsDown {
                    Section {
                        Button("Filters wissen", role: .destructive) {
                            filter.status = nil
                            filter.origin = nil
                        }
                    }
                }
            } label: {
                filterLabel
            }
            .accessibilityLabel("Filter")
            .accessibilityValue(summary)

            Spacer(minLength: 0)

            Button {
                withAnimation(.snappy(duration: 0.22)) { isGrid.toggle() }
                PaveHaptics.selection()
            } label: {
                Image(isGrid ? .iconListBulletSolid : .iconSquares2X2Solid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.surfaceTint, in: .rect(cornerRadius: 10))
                    .contentShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.pave)
            .accessibilityLabel(isGrid ? "Toon als lijst" : "Toon als raster")
        }
        .onChange(of: filter.status) { PaveHaptics.selection() }
        .onChange(of: filter.origin) { PaveHaptics.selection() }
        .onChange(of: filter.order) { PaveHaptics.selection() }
    }

    private var filterLabel: some View {
        HStack(spacing: 8) {
            Image(.iconFunnelSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text("Filter")
                .textStyle(.bodyMedium)
            if activeCount > 0 {
                Text("\(activeCount)")
                    .textStyle(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.brandGreen, in: .circle)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(activeCount > 0 ? Color.brandGreen : Color.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 10))
        .overlay {
            if activeCount > 0 {
                RoundedRectangle(cornerRadius: 10).strokeBorder(Color.brandGreen.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(.rect(cornerRadius: 10))
    }

    /// What VoiceOver reads on the Filter button: which filters are on and how the list is sorted.
    private var summary: String {
        let parts = [filter.status?.title, filter.origin?.title].compactMap(\.self)
        return (parts.isEmpty ? ["Geen filters"] : parts).joined(separator: ", ") + ", " + filter.order.title.lowercased()
    }
}

#Preview {
    @Previewable @State var filter = VaultFilter()
    @Previewable @State var isGrid = true
    VaultFilterBar(filter: $filter, isGrid: $isGrid)
        .padding()
        .background(Color.canvas)
}
