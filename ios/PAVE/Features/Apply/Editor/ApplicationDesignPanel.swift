import PAVECore
import SwiftUI

/// How it looks: the template, the colour, the photo, and which parts of the CV show in which order.
struct ApplicationDesignPanel: View {
    let model: ApplicationStudioModel
    let photo: UIImage?

    /// The PAVE theme colours, in their shade that reads well on white paper.
    private static let colors: [PaveThemeColor] = PaveThemeColor.allCases.filter { $0 != .custom }

    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section(ApplyMessages.templates) {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(ApplicationTemplate.allCases) { template in
                            ApplicationTemplateThumbnail(draft: model.draft, template: template, photo: photo, isSelected: model.draft.template == template) {
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { model.update { $0.template = template } }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            section(ApplyMessages.color) {
                HStack(spacing: 12) {
                    ForEach(Self.colors, id: \.self) { theme in
                        let color = theme.accent
                        let isOn = model.draft.accent == color
                        Button {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { model.update { $0.accent = color } }
                        } label: {
                            Circle()
                                .fill(Color(uiColor: UIColor(hex: color)))
                                .frame(width: 30, height: 30)
                                .overlay { Circle().strokeBorder(Color.panel, lineWidth: isOn ? 3 : 0) }
                                .overlay { Circle().strokeBorder(Color(uiColor: UIColor(hex: color)), lineWidth: isOn ? 2 : 0).padding(-3) }
                                .frame(width: 44, height: 44)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.pave)
                        .accessibilityLabel(SettingsMessages.title(theme))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle(ApplyMessages.photo, isOn: Binding(get: { model.draft.showsPhoto && photo != nil }, set: { value in model.update { $0.showsPhoto = value } }))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .tint(.paveAccentFill)
                    .disabled(photo == nil)
                if photo == nil {
                    Text(ApplyMessages.photoMissing)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
            }
            if model.document == .cv {
                section(ApplyMessages.sections) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.draft.cv.sections.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 10) {
                                Toggle(isOn: Binding(get: { model.draft.cv.sections[index].isVisible }, set: { value in model.update { $0.cv.sections[index].isVisible = value } })) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ApplyMessages.section(item.kind))
                                            .textStyle(.bodyMedium)
                                            .foregroundStyle(Color.ink)
                                        Text("\(item.entries.count)")
                                            .textStyle(.caption)
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                }
                                .tint(.paveAccentFill)
                                move(index, by: -1)
                                move(index, by: 1)
                            }
                            .frame(minHeight: 52)
                            if index < model.draft.cv.sections.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func move(_ index: Int, by step: Int) -> some View {
        let target = index + step
        let canMove = model.draft.cv.sections.indices.contains(target)
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { model.moveSection(from: IndexSet(integer: index), to: step > 0 ? target + 1 : target) }
        } label: {
            Image(.iconChevronDown)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(12)
                .rotationEffect(.degrees(step < 0 ? 180 : 0))
                .foregroundStyle(canMove ? Color.ink : Color.inkMuted.opacity(0.4))
                .frame(width: 36, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .disabled(!canMove)
        .accessibilityLabel(step < 0 ? "Omhoog" : "Omlaag")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
