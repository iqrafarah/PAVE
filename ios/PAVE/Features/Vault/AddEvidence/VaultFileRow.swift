import PAVECore
import SwiftUI

/// The chosen file: its kind, name and size, with a cross to take it away again.
struct VaultFileRow: View {
    let upload: VaultUpload
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(upload.isImage ? .iconPhotoSolid : .iconDocumentSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.brandGreen)
                .frame(width: 41, height: 41)
                .background(Color.hairline, in: .rect(cornerRadius: 7))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(upload.fileName)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(upload.summary)
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRemove) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("\(upload.fileName) weghalen")
        }
        .padding(.leading, 15)
        .padding(.trailing, 4)
        .padding(.vertical, 15)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VaultFileRow(upload: VaultUpload(data: Data(count: 2_400_000), fileName: "LiveWall-eindstage-verslag.pdf", mimeType: "application/pdf")) {}
        .padding(24)
}
