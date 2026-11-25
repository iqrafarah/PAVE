import PAVECore
import SwiftUI

/// Scanning a QR code: an employer's card opens here; a shared profile of someone else opens its page.
struct ShareScanSheet: View {
    let model: SharingModel
    let onShareBack: (FairEmployer) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// What was just recognised: an employer, one vacancy on a poster, or an employer's inbox.
    @State private var scanned: ShareLinks.Scanned?
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Group {
                if case .inbox(let slug, let key) = scanned {
                    EmployerInboxView(slug: slug, key: key)
                } else if let (slug, vacancyID) = employerOfScan {
                    FairEmployerLoader(slug: slug, vacancyID: vacancyID, model: model) { employer in
                        onShareBack(employer)
                        dismiss()
                    }
                } else if ShareScanner.isAvailable {
                    ZStack(alignment: .bottom) {
                        ShareScanner { found in Task { await open(found) } }
                            .ignoresSafeArea()
                        Text(problem ?? SharingMessages.scanHint)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .padding(14)
                            .background(Color.panel, in: .rect(cornerRadius: 14))
                            .padding(20)
                    }
                } else {
                    PaveEmptyState(icon: .iconCamera, title: SharingMessages.scan, message: "Deze iPhone kan hier geen QR-codes scannen. Gebruik de Camera-app.")
                }
            }
            .background(Color.canvas)
            .navigationTitle(scanned == nil ? SharingMessages.scan : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if scanned != nil {
                        PaveBackButton(label: SharingMessages.scanAgain) {
                            scanned = nil
                            problem = nil
                        }
                    } else {
                        Button(SharingMessages.cancel) { dismiss() }
                    }
                }
            }
        }
    }

    private var employerOfScan: (String, String?)? {
        switch scanned {
        case .employer(let slug): (slug, nil)
        case .vacancy(let slug, let id): (slug, id)
        default: nil
        }
    }

    private func open(_ found: ShareLinks.Scanned) async {
        switch found {
        case .employer, .vacancy, .inbox:
            guard scanned == nil else { return }
            scanned = found
        case .share(let code):
            // Someone else's profile opens on its web page, as for anyone without PAVE.
            if let base = model.webURL {
                openURL(ShareLinks.share(code, base: base))
                dismiss()
            }
        }
    }
}
