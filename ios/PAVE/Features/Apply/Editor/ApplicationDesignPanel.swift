import PAVECore
import SwiftUI

/// How it looks: the design, its colours, the photo, and which parts of the CV show in which order.
struct ApplicationDesignPanel: View {
    let model: ApplicationStudioModel
    let photo: UIImage?

    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section(ApplyMessages.templates) {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(ApplicationTemplate.allCases) { template in
                            ApplicationTemplateThumbnail(draft: model.draft, template: template, photo: photo, isSelected: model.draft.template == template) {
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { model.choose(template) }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            section(ApplyMessages.color) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ApplicationPalette.allCases, id: \.self) { palette in
                            let isOn = model.draft.palette == palette
                            Button {
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { model.update { $0.palette = palette } }
                            } label: {
                                swatch(palette, isOn: isOn)
                            }
                            .buttonStyle(.pave)
                            .accessibilityLabel(ApplyMessages.palette(palette))
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
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
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(ApplyMessages.showVerified, isOn: Binding(get: { model.draft.marksVerified }, set: { value in model.update { $0.showsVerified = value } }))
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .tint(.paveAccentFill)
                    Text(model.draft.cv.sections.contains { $0.entries.contains(where: \.isVerified) } ? ApplyMessages.showVerifiedHint : ApplyMessages.nothingVerified)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    /// A palette as Canva shows one: its dark, its colour and its soft tint side by side.
    private func swatch(_ palette: ApplicationPalette, isOn: Bool) -> some View {
        HStack(spacing: 0) {
            ApplicationTheme.color(palette.dark)
            ApplicationTheme.color(palette.accent)
            ApplicationTheme.color(palette.tint)
        }
        .frame(width: 54, height: 30)
        .clipShape(.rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .padding(3)
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(isOn ? Color.paveAccent : Color.clear, lineWidth: 2) }
        .frame(minWidth: 60, minHeight: 44)
        .contentShape(.rect)
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
