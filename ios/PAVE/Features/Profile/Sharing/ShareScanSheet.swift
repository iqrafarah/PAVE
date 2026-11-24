import PAVECore
import SwiftUI

/// Scanning a QR code: an employer's card opens here; a shared profile of someone else opens its page.
struct ShareScanSheet: View {
    let model: SharingModel
    let onShareBack: (FairEmployer) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var employer: FairEmployer?
    @State private var problem: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if let employer {
                    FairEmployerView(employer: employer) {
                        dismiss()
                        onShareBack(employer)
                    }
                } else if ShareScanner.isAvailable {
                    ZStack(alignment: .bottom) {
                        ShareScanner { found in Task { await open(found) } }
                            .ignoresSafeArea()
                        Text(problem ?? (isLoading ? "Even kijken…" : SharingMessages.scanHint))
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
            .navigationTitle(employer?.name ?? SharingMessages.scan)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(SharingMessages.cancel) { dismiss() } } }
        }
    }

    private func open(_ found: ShareLinks.Scanned) async {
        switch found {
        case .employer(let slug):
            guard let service = model.service else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                employer = try await service.employer(slug: slug)
            } catch {
                problem = "Deze werkgever kon niet worden geladen. Probeer het opnieuw."
            }
        case .share(let code):
            // Someone else's profile opens on its web page, as for anyone without PAVE.
            if let base = model.webURL {
                openURL(ShareLinks.share(code, base: base))
                dismiss()
            }
        }
    }
}
