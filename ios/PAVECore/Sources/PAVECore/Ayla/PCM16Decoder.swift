import Foundation

/// Turns Ayla's voice (raw pcm16, little-endian, 24 kHz, mono) into samples between -1 and 1.
/// A piece from the network can end in the middle of a sample; that byte waits for the next piece.
public struct PCM16Decoder: Sendable {
    public static let sampleRate = 24_000.0

    private var leftover: UInt8?

    public init() {}

    public mutating func samples(from data: Data) -> [Float] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(data.count + 1)
        if let leftover { bytes.append(leftover) }
        bytes.append(contentsOf: data)
        let usable = bytes.count - bytes.count % 2
        leftover = usable < bytes.count ? bytes[usable] : nil

        var samples = [Float]()
        samples.reserveCapacity(usable / 2)
        var index = 0
        while index < usable {
            let value = Int16(bitPattern: UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8)
            samples.append(Float(value) / 32768)
            index += 2
        }
        return samples
    }
}
