import AVFoundation
import Testing
@testable import PAVE

struct VoiceTurnRecorderTests {
    private func buffer(seconds: Double, sampleRate: Double = 48_000) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for index in 0..<Int(frames) { buffer.floatChannelData![0][index] = sin(Float(index) * 0.05) * 0.3 }
        return buffer
    }

    @Test func keepsTheMicrophoneAt16kHz() throws {
        let recorder = VoiceTurnRecorder()
        for _ in 0..<10 { recorder.append(buffer(seconds: 0.1)) }
        #expect(abs(recorder.position - 16_000) < 400)
        let wav = try #require(recorder.wav(from: 0))
        #expect(abs(wav.count - (44 + 32_000)) < 800)
    }

    @Test func aMarkStaysValidAfterAReset() throws {
        let recorder = VoiceTurnRecorder()
        recorder.append(buffer(seconds: 0.5))
        let mark = recorder.position
        recorder.reset()
        #expect(recorder.position == mark)
        #expect(recorder.wav(from: mark) == nil)
        recorder.append(buffer(seconds: 0.5))
        let wav = try #require(recorder.wav(from: mark))
        #expect(abs(wav.count - (44 + 16_000)) < 800)
    }
}
