import Compression
import Foundation
import Testing
@testable import PAVECore

struct VaultWordTextTests {
    /// A zip file as Word writes it: each part deflated (or stored), with a central directory at the end.
    private func zip(_ parts: [(name: String, text: String, deflate: Bool)]) -> Data {
        var file = [UInt8]()
        var directory = [UInt8]()
        func le16(_ value: Int) -> [UInt8] { [UInt8(value & 0xff), UInt8(value >> 8 & 0xff)] }
        func le32(_ value: Int) -> [UInt8] { le16(value & 0xffff) + le16(value >> 16 & 0xffff) }
        for part in parts {
            let raw = [UInt8](part.text.utf8)
            var body = raw
            if part.deflate {
                var output = [UInt8](repeating: 0, count: raw.count + 1024)
                let written = compression_encode_buffer(&output, output.count, raw, raw.count, nil, COMPRESSION_ZLIB)
                body = Array(output.prefix(written))
            }
            let name = [UInt8](part.name.utf8)
            let method = part.deflate ? 8 : 0
            let offset = file.count
            file += le32(0x0403_4b50) + le16(20) + le16(0) + le16(method) + le32(0) + le32(0)
            file += le32(body.count) + le32(raw.count) + le16(name.count) + le16(0) + name + body
            directory += le32(0x0201_4b50) + le16(20) + le16(20) + le16(0) + le16(method) + le32(0) + le32(0)
            directory += le32(body.count) + le32(raw.count) + le16(name.count) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0)
            directory += le32(offset) + name
        }
        let start = file.count
        file += directory
        file += le32(0x0605_4b50) + le16(0) + le16(0) + le16(parts.count) + le16(parts.count) + le32(directory.count) + le32(start) + le16(0)
        return Data(file)
    }

    @Test func aWordDocumentIsReadWithItsLetterhead() throws {
        let document = """
        <w:document><w:body><w:p><w:r><w:t>Certificaat</w:t></w:r></w:p>\
        <w:p><w:r><w:t xml:space="preserve">Professional Scrum Master I </w:t></w:r><w:r><w:t>&amp; Agile</w:t></w:r></w:p>\
        <w:p><w:r><w:t>Behaald:</w:t><w:tab/><w:t>12 juni 2025</w:t></w:r></w:p></w:body></w:document>
        """
        let header = "<w:hdr><w:p><w:r><w:t>Scrum.org</w:t></w:r></w:p></w:hdr>"
        let data = zip([
            ("[Content_Types].xml", "<Types/>", false),
            ("word/document.xml", document, true),
            ("word/header1.xml", header, false),
        ])
        let text = try #require(VaultWordText.text(of: data))
        #expect(text == "Scrum.org\n\nCertificaat\nProfessional Scrum Master I & Agile\nBehaald:\t12 juni 2025")
    }

    @Test func thePicturesOfAWordDocumentComeOutInOrder() {
        let png = "\u{89}PNG" + String(repeating: "x", count: 2000)
        let data = zip([
            ("word/document.xml", "<w:document/>", true),
            ("word/media/image10.png", png + "10", true),
            ("word/media/image2.png", png + "2", false),
            ("word/media/icon.png", "\u{89}PNG tiny", false),
            ("word/media/drawing.emf", png, false),
        ])
        let pictures = VaultWordText.images(of: data).map { String(decoding: $0, as: UTF8.self) }
        #expect(pictures.map { String($0.suffix(2)) } == ["x2", "10"])
    }

    @Test func somethingElseGivesNothing() {
        #expect(VaultWordText.text(of: Data("geen zip".utf8)) == nil)
        #expect(VaultWordText.text(of: zip([("word/other.xml", "<x/>", true)])) == nil)
    }
}
