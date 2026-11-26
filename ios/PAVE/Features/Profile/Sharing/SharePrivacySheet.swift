import SwiftUI

/// What sharing means, in plain words: what the recipient may do, how long, what stays and who makes PAVE. The concept
/// test showed people did not know access is only for a while (rapport p. 21).
struct SharePrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(SharingMessages.privacyText, id: \.0) { title, text in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).textStyle(.listTitle).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
                            Text(text).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.canvas)
            .navigationTitle(SharingMessages.howItWorks)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done) { dismiss() } } }
        }
    }
}
