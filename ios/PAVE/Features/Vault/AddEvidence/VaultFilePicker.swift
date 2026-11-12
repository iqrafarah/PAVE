import PAVECore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Where a file comes from: the Files app, or a photo from the library.
enum VaultFileSource: Identifiable {
    case files
    case photos

    var id: Self { self }
}

extension View {
    /// Opens Files or Photos when `source` is set and hands back the file, already checked like the vault checks it.
    func vaultFilePicker(
        source: Binding<VaultFileSource?>,
        role: VaultFileRole,
        onPick: @escaping (Result<VaultUpload, VaultUpload.Problem>) -> Void
    ) -> some View {
        modifier(VaultFilePicker(source: source, role: role, onPick: onPick))
    }
}

private struct VaultFilePicker: ViewModifier {
    @Binding var source: VaultFileSource?
    let role: VaultFileRole
    let onPick: (Result<VaultUpload, VaultUpload.Problem>) -> Void

    @State private var photo: PhotosPickerItem?

    private var types: [UTType] {
        let images: [UTType] = [.jpeg, .png, .heic]
        guard role == .document else { return images }
        let word = ["com.microsoft.word.doc", "org.openxmlformats.wordprocessingml.document"].compactMap(UTType.init)
        return [.pdf, .plainText] + word + images
    }

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: showing(.files), allowedContentTypes: types) { result in
                guard case .success(let url) = result else { return }
                onPick(Self.upload(from: url, role: role))
            }
            .photosPicker(isPresented: showing(.photos), selection: $photo, matching: .images, preferredItemEncoding: .compatible)
            .onChange(of: photo) { _, item in
                guard let item else { return }
                photo = nil
                Task { onPick(await Self.upload(from: item, role: role)) }
            }
    }

    private func showing(_ wanted: VaultFileSource) -> Binding<Bool> {
        Binding(get: { source == wanted }, set: { if !$0, source == wanted { source = nil } })
    }

    private static func upload(from url: URL, role: VaultFileRole) -> Result<VaultUpload, VaultUpload.Problem> {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > VaultUpload.maximumBytes {
            return .failure(.tooLarge)
        }
        guard let data = try? Data(contentsOf: url) else { return .failure(.empty) }
        let mimeType = VaultUpload.mimeType(forExtension: url.pathExtension)
            ?? UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        let upload = VaultUpload(data: data, fileName: url.lastPathComponent, mimeType: mimeType, role: role)
        if let problem = upload.problem { return .failure(problem) }
        return .success(upload)
    }

    /// Photos become a JPEG: every phone and the web can show it, and the copy leaves out where the photo was taken.
    private static func upload(from item: PhotosPickerItem, role: VaultFileRole) async -> Result<VaultUpload, VaultUpload.Problem> {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85)
        else { return .failure(.unsupportedType) }
        let name = "Foto \(Date.now.formatted(.iso8601.year().month().day())).jpeg"
        let upload = VaultUpload(data: jpeg, fileName: name, mimeType: "image/jpeg", role: role)
        if let problem = upload.problem { return .failure(problem) }
        return .success(upload)
    }
}
