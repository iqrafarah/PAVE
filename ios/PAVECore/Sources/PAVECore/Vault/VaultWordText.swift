import Compression
import Foundation

/// The text of a Word document (.docx), so Ayla can read it like a PDF. A .docx is a zip file with the text in
/// `word/document.xml`, and the letterhead often in `word/header1.xml`. Only reading, on the device; an old .doc file
/// cannot be read this way and gives nothing.
public enum VaultWordText {
    /// Larger parts are skipped rather than unpacked.
    static let maximumPartSize = 20_000_000

    public static func text(of data: Data) -> String? {
        guard let parts = try? zipEntries(in: data) else { return nil }
        let names = parts.keys.filter { name in
            name == "word/document.xml" || (name.hasPrefix("word/header") && name.hasSuffix(".xml")) || (name.hasPrefix("word/footer") && name.hasSuffix(".xml"))
        }
        // The letterhead first, then the document, then the footers, as you read the page.
        let order = { (name: String) in name.hasPrefix("word/header") ? 0 : name == "word/document.xml" ? 1 : 2 }
        let texts = names.sorted { (order($0), $0) < (order($1), $1) }.compactMap { name -> String? in
            guard let xml = parts[name].flatMap({ try? $0() }).flatMap({ String(data: $0, encoding: .utf8) }) else { return nil }
            let text = plainText(fromWordXML: xml)
            return text.isEmpty ? nil : text
        }
        let joined = texts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    /// The pictures in a Word document, such as the logo in its letterhead and photos in a report: PNG and JPEG only,
    /// in the order Word numbered them, without tiny icons.
    public static func images(of data: Data, limit: Int = 4) -> [Data] {
        guard let parts = try? zipEntries(in: data) else { return [] }
        let names = parts.keys
            .filter { name in name.hasPrefix("word/media/") && [".png", ".jpg", ".jpeg"].contains { name.lowercased().hasSuffix($0) } }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return names.compactMap { parts[$0].flatMap { try? $0() } }.filter { $0.count >= 1500 }.prefix(limit).map(\.self)
    }

    /// The words of WordprocessingML: each `<w:t>` run, with a new line for each paragraph and break, and tabs kept.
    static func plainText(fromWordXML xml: String) -> String {
        var result = ""
        let pattern = /<w:t(?:\s[^>]*)?>([^<]*)<\/w:t>|<\/w:p>|<w:tab\/>|<w:br\/>|<w:cr\/>/
        for match in xml.matches(of: pattern) {
            if let text = match.output.1 {
                result += decodeEntities(String(text))
            } else if match.output.0 == "<w:tab/>" {
                result += "\t"
            } else {
                result += "\n"
            }
        }
        return result
            .replacing(/[ \t]+\n/, with: "\n")
            .replacing(/\n{3,}/, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: Zip

    private enum ZipError: Error { case notAZip }

    /// The entries of a zip file by name, each unpacked only when asked for.
    static func zipEntries(in data: Data) throws -> [String: () throws -> Data] {
        let bytes = [UInt8](data)
        guard let end = endOfCentralDirectory(in: bytes) else { throw ZipError.notAZip }
        let count = Int(uint16(bytes, end + 10))
        var offset = Int(uint32(bytes, end + 16))
        var entries: [String: () throws -> Data] = [:]
        for _ in 0..<count {
            guard offset + 46 <= bytes.count, uint32(bytes, offset) == 0x0201_4b50 else { break }
            let method = uint16(bytes, offset + 10)
            let compressedSize = Int(uint32(bytes, offset + 20))
            let size = Int(uint32(bytes, offset + 24))
            let nameLength = Int(uint16(bytes, offset + 28))
            let extraLength = Int(uint16(bytes, offset + 30))
            let commentLength = Int(uint16(bytes, offset + 32))
            let localHeader = Int(uint32(bytes, offset + 42))
            guard offset + 46 + nameLength <= bytes.count else { break }
            let name = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)
            entries[name] = {
                guard localHeader + 30 <= bytes.count, uint32(bytes, localHeader) == 0x0403_4b50 else { throw ZipError.notAZip }
                let start = localHeader + 30 + Int(uint16(bytes, localHeader + 26)) + Int(uint16(bytes, localHeader + 28))
                guard start + compressedSize <= bytes.count, size <= maximumPartSize else { throw ZipError.notAZip }
                let compressed = Array(bytes[start..<(start + compressedSize)])
                switch method {
                case 0: return Data(compressed)
                case 8: return try inflate(compressed, size: size)
                default: throw ZipError.notAZip
                }
            }
            offset += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func endOfCentralDirectory(in bytes: [UInt8]) -> Int? {
        guard bytes.count >= 22 else { return nil }
        let lowest = max(0, bytes.count - 22 - 65_535)
        var index = bytes.count - 22
        while index >= lowest {
            if uint32(bytes, index) == 0x0605_4b50 { return index }
            index -= 1
        }
        return nil
    }

    /// Zip's "deflate" is raw DEFLATE, which is what Apple calls `COMPRESSION_ZLIB`.
    private static func inflate(_ compressed: [UInt8], size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = [UInt8](repeating: 0, count: size)
        let written = compressed.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { target in
                compression_decode_buffer(target.baseAddress!, size, source.baseAddress!, compressed.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ZipError.notAZip }
        return Data(output)
    }

    private static func uint16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        guard offset + 2 <= bytes.count else { return 0 }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func uint32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        return UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
