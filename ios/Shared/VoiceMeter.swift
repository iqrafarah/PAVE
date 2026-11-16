import Accelerate
import Foundation

/// How loud the user (microphone) and Ayla (speaker) are right now, from 0 to 1, and how that sound is spread over
/// 24 frequency bands (for the equalizer ring around the orb, as in the voice demo).
/// The audio threads write it many times a second and the orb reads it every frame,
/// so it is a small locked value instead of observable state that would redraw the whole screen.
nonisolated final class VoiceMeter: @unchecked Sendable {
    static let bandCount = 24

    private let lock = NSLock()
    private var microphone: Float = 0
    private var speaker: Float = 0
    private var microphoneSpectrum = [Float](repeating: 0, count: VoiceMeter.bandCount)
    private var speakerSpectrum = [Float](repeating: 0, count: VoiceMeter.bandCount)

    var microphoneLevel: Float { lock.withLock { microphone } }
    var speakerLevel: Float { lock.withLock { speaker } }
    var microphoneBands: [Float] { lock.withLock { microphoneSpectrum } }
    var speakerBands: [Float] { lock.withLock { speakerSpectrum } }

    func update(microphone level: Float) {
        lock.withLock { microphone = microphone * 0.6 + level * 0.4 }
    }

    func update(speaker level: Float) {
        lock.withLock { speaker = speaker * 0.6 + level * 0.4 }
    }

    func update(microphoneBands bands: [Float]) {
        lock.withLock { Self.smooth(&microphoneSpectrum, towards: bands) }
    }

    func update(speakerBands bands: [Float]) {
        lock.withLock { Self.smooth(&speakerSpectrum, towards: bands) }
    }

    func reset() {
        lock.withLock {
            microphone = 0
            speaker = 0
            microphoneSpectrum = [Float](repeating: 0, count: Self.bandCount)
            speakerSpectrum = [Float](repeating: 0, count: Self.bandCount)
        }
    }

    private static func smooth(_ current: inout [Float], towards bands: [Float]) {
        guard bands.count == current.count else { return }
        for index in current.indices { current[index] = current[index] * 0.6 + bands[index] * 0.4 }
    }

    /// The loudness of an audio buffer, scaled so normal speech reaches about 0.6.
    static func level(of samples: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count { sum += samples[index] * samples[index] }
        let rms = (sum / Float(count)).squareRoot()
        return min(1, rms * 6)
    }

    private static let fftSize = 256
    /// The FFT setup is only read after it is made, and every call uses its own buffers, so the two audio threads may share it.
    nonisolated(unsafe) private static let fft = vDSP.FFT(log2n: 8, radix: .radix2, ofType: DSPSplitComplex.self)
    private static let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: fftSize, isHalfWindow: false)

    /// The sound in 24 bands, like the browser's analyser in the voice demo: two FFT bins of a 256-point FFT
    /// per band (at 48 kHz that is about 190 Hz to 9 kHz, where speech lives), in decibels from -100 to -30 as 0 to 1.
    static func bands(of samples: UnsafePointer<Float>, count: Int, sampleRate: Double) -> [Float] {
        guard count >= fftSize, let fft else { return [Float](repeating: 0, count: bandCount) }
        let input = Array(UnsafeBufferPointer(start: samples + (count - fftSize), count: fftSize))
        let windowed = vDSP.multiply(input, window)
        var real = [Float](repeating: 0, count: fftSize / 2)
        var imaginary = [Float](repeating: 0, count: fftSize / 2)
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedPointer in
                    windowedPointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(fftSize / 2))
                    }
                }
                fft.forward(input: split, output: &split)
                vDSP.absolute(split, result: &magnitudes)
            }
        }
        // The browser's analyser used 48 kHz; pick the same frequencies at this buffer's sample rate.
        let binWidth = sampleRate / Double(fftSize)
        let browserBinWidth = 48_000.0 / Double(fftSize)
        var bands = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            var sum: Float = 0
            for offset in 1...2 {
                let frequency = Double(band * 2 + offset) * browserBinWidth
                let bin = min(fftSize / 2 - 1, max(0, Int((frequency / binWidth).rounded())))
                let amplitude = magnitudes[bin] / Float(fftSize)
                let decibels = 20 * log10(max(amplitude, 1e-7))
                sum += min(1, max(0, (decibels + 100) / 70))
            }
            bands[band] = sum / 2
        }
        return bands
    }
}
