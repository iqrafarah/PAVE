import Foundation

/// A recording as a WAV file: 16-bit mono samples behind the standard 44-byte header, as `ayla-listen` expects.
public enum AylaWAV {
    public static func data(samples: [Int16], sampleRate: Int) -> Data {
        let byteCount = samples.count * 2
        var data = Data(capacity: 44 + byteCount)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(byteCount))
        // Apple devices are little-endian, as WAV is.
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
