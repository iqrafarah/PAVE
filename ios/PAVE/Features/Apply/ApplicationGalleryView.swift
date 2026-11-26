import PAVECore
import SwiftUI

/// The first step, as in Canva: designs to choose from, already filled with your own data, filtered by kind.
struct ApplicationGalleryView: View {
    let model: ApplicationStudioModel
    let photo: UIImage?

    @State private var filter: Filter = .all
    @State private var chosen: ApplicationTemplate?
    @Environment(\.paveReduceMotion) private var reduceMotion

    enum Filter: Hashable, CaseIterable {
        case all, photo, business, creative, minimal, elegant

        func includes(_ template: ApplicationTemplate) -> Bool {
            switch self {
            case .all: true
            case .photo: template.hasPhoto
            case .business: template.styles.contains(.business)
            case .creative: template.styles.contains(.creative)
            case .minimal: template.styles.contains(.minimal)
            case .elegant: template.styles.contains(.elegant)
            }
        }

        var title: String {
            switch self {
            case .all: ApplyMessages.allDesigns
            case .photo: ApplyMessages.withPhoto
            case .business: ApplyMessages.style(.business)
            case .creative: ApplyMessages.style(.creative)
            case .minimal: ApplyMessages.style(.minimal)
            case .elegant: ApplyMessages.style(.elegant)
            }
        }
    }

    private var shown: [ApplicationTemplate] { ApplicationTemplate.allCases.filter(filter.includes) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ApplyMessages.chooseDesign)
                        .textStyle(.emptyTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(ApplyMessages.chooseDesignHint(model.draft.vacancy))
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Filter.allCases, id: \.self) { option in
                            let isOn = filter == option
                            Button(option.title) {
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { filter = option }
                            }
                            .textStyle(.chip)
                            .foregroundStyle(isOn ? Color.white : Color.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
                            .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
                            .frame(minHeight: 44)
                            .contentShape(.capsule)
                            .buttonStyle(.pave)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                }
                .scrollIndicators(.hidden)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 158, maximum: 260), spacing: 14, alignment: .top)], spacing: 16) {
                    ForEach(shown) { template in
                        ApplicationGalleryCard(draft: model.preview(template), photo: photo, isSelected: chosen == template) {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { chosen = template }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: filter)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            if let chosen {
                PavePrimaryButton(title: ApplyMessages.useDesign(chosen)) { model.choose(chosen) }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.canvas.opacity(0.96))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.15), value: chosen)
    }
}
