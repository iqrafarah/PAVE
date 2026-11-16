import PAVECore
import SwiftUI

/// Changing evidence, in the style of adding it: one page with the details, the cover, the documents, the skills and
/// Ayla's permission. You close it by swiping down; with changes it first asks whether to stop. A confirmed item says up
/// front that a change means it has to be confirmed again, and asks once more before saving.
struct VaultEvidenceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var edit: VaultEditEvidenceModel
    @State private var documentSource: VaultFileSource?
    @State private var confirmsDiscard = false
    @State private var confirmsReconfirmation = false
    @State private var isTyping = false
    @State private var height: CGFloat = 800

    init(vault: VaultModel, item: VaultItem) {
        _edit = State(initialValue: VaultEditEvidenceModel(vault: vault, item: item))
    }

    private var isShort: Bool { verticalSizeClass == .compact || height < 720 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if edit.item.changeNeedsReconfirmation {
                        PaveNotice(title: VaultMessages.reconfirmTitle, message: VaultMessages.reconfirmMessage)
                    }
                    VaultEvidenceForm(draft: $edit.draft, missing: [], folders: edit.folders)
                    VaultLookSection(
                        logo: edit.logo,
                        cover: edit.cover,
                        wantsCover: $edit.wantsCover,
                        title: edit.draft.title,
                        category: edit.draft.category,
                        onPick: { edit.pick($0) },
                        onRemoveLogo: edit.removeLogo,
                        onRemoveCover: edit.removeCover
                    )
                    VaultDocumentsSection(
                        count: edit.keptDocuments.count + edit.newDocuments.count,
                        canAdd: edit.canAddDocument,
                        onChoose: { documentSource = $0 }
                    ) {
                        ForEach(edit.keptDocuments) { file in
                            VaultRemoteFileRow(file: file) { withAnimation(.snappy) { edit.remove(file) } }
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }
                        ForEach(edit.newDocuments, id: \.checksum) { upload in
                            VaultFileRow(upload: upload) { withAnimation(.snappy) { edit.remove(upload) } }
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }
                    }
                    VaultSkillsPicker(skills: $edit.skills, known: edit.knownSkills, ayla: edit.ayla, draft: edit.draft)
                    VaultAylaConsentCard(isOn: $edit.allowsAyla, hasFile: edit.hasFile)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .environment(\.isShortSheet, isShort)
            }
            .scrollDismissesKeyboard(.interactively)
            if !isTyping {
                footer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .tint(.paveAccent)
        .animation(.easeOut(duration: 0.2), value: isTyping)
        .animation(.snappy(duration: 0.3), value: edit.keptDocuments)
        .animation(.snappy(duration: 0.3), value: edit.newDocuments)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isTyping = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isTyping = false }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheetDismissGuard(isBlocked: edit.hasChanges || edit.isSaving) {
            if !edit.isSaving { confirmsDiscard = true }
        }
        .vaultFilePicker(source: $documentSource, role: .document) { edit.pick($0) }
        .confirmationDialog(VaultMessages.discardChangesTitle, isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Wijzigingen weggooien", role: .destructive) { dismiss() }
            Button("Verder met aanpassen", role: .cancel) {}
        }
        .confirmationDialog(VaultMessages.reconfirmQuestion, isPresented: $confirmsReconfirmation, titleVisibility: .visible) {
            Button("Bewaren") { Task { await save() } }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text(VaultMessages.reconfirmMessage)
        }
    }

    private var header: some View {
        HStack {
            Text("Bewijs aanpassen")
                .textStyle(isShort ? .label : .listTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            VaultStatusBadge(status: edit.item.status)
        }
        .frame(height: isShort ? 36 : 44)
        .padding(.horizontal, 24)
        .padding(.top, isShort ? 8 : 22)
        .padding(.bottom, isShort ? 6 : 12)
    }

    private var footer: some View {
        PavePrimaryButton(title: "Bewaren", loadingTitle: "Bewaren…", isLoading: edit.isSaving) {
            if edit.needsReconfirmation { confirmsReconfirmation = true } else { Task { await save() } }
        }
        .disabled(!edit.hasChanges)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, isShort ? 6 : 12)
        .background(Color.white)
        .overlay(alignment: .top) {
            if let problem = edit.problem {
                PaveInlineError(message: problem)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .alignmentGuide(.top) { $0[.bottom] }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: edit.problem)
    }

    private func save() async {
        if await edit.save() { dismiss() }
    }
}
