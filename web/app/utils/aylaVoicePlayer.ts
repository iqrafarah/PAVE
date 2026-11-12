// Plays Ayla's streamed voice (pcm16, 24 kHz, mono) with the Web Audio API, piece by piece as it arrives
// (docs/ayla.md, section 6), and measures how loud it is for the orb.

export interface VoicePlayer {
  /** Plays the stream; resolves with whether any audio was heard, once it has finished playing (or was stopped). */
  play: (stream: ReadableStream<Uint8Array>, onFirstAudio: () => void) => Promise<boolean>;
  stop: () => void;
  /** How loud Ayla is right now, from 0 to 1. */
  getLevel: () => number;
  getBands: (count: number) => number[];
  blip: (name: 'listen' | 'think' | 'end') => void;
  close: () => void;
}

export function getLevel(analyser: AnalyserNode, buffer: Float32Array<ArrayBuffer>) {
  analyser.getFloatTimeDomainData(buffer);
  let sum = 0;
  for (const sample of buffer) sum += sample * sample;
  return Math.min(1, Math.sqrt(sum / buffer.length) * 4);
}

export function createVoicePlayer(): VoicePlayer {
  const context = new AudioContext({ sampleRate: VOICE_SAMPLE_RATE });
  const analyser = context.createAnalyser();
  analyser.fftSize = 512;
  analyser.connect(context.destination);
  const levelBuffer = new Float32Array(analyser.fftSize);
  const bandBuffer = new Uint8Array(analyser.frequencyBinCount);
  let sources: AudioBufferSourceNode[] = [];
  let nextStart = 0;
  let playing = 0;
  let finish: (() => void) | null = null;

  function stop() {
    playing += 1;
    for (const source of sources) {
      try {
        source.stop();
      } catch {
        // Already stopped.
      }
    }
    sources = [];
    nextStart = 0;
    finish?.();
  }

  async function play(stream: ReadableStream<Uint8Array>, onFirstAudio: () => void) {
    stop();
    const current = playing;
    await context.resume();
    const decode = createPcm16Decoder();
    const reader = stream.getReader();
    let heardAny = false;
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done || current !== playing) break;
        const samples = decode(value);
        if (!samples.length) continue;
        if (!heardAny) {
          heardAny = true;
          onFirstAudio();
        }
        const buffer = context.createBuffer(1, samples.length, VOICE_SAMPLE_RATE);
        buffer.copyToChannel(samples, 0);
        const source = context.createBufferSource();
        source.buffer = buffer;
        source.connect(analyser);
        nextStart = Math.max(nextStart, context.currentTime);
        source.start(nextStart);
        nextStart += buffer.duration;
        sources.push(source);
      }
    } catch {
      // The stream broke off: what arrived still plays.
    } finally {
      reader.cancel().catch(() => {});
    }
    if (current !== playing || !heardAny) return heardAny;
    // Wait until the last piece has been played, unless Ayla is stopped first.
    const remaining = Math.max(0, nextStart - context.currentTime);
    await new Promise<void>((resolve) => {
      const timer = setTimeout(resolve, remaining * 1000);
      finish = () => {
        clearTimeout(timer);
        resolve();
      };
    });
    finish = null;
    return heardAny;
  }

  return {
    play,
    stop,
    getLevel: () => getLevel(analyser, levelBuffer),
    getBands: (count) => getBands(analyser, bandBuffer, count),
    blip: (name) => playBlip(context, name),
    close: () => {
      stop();
      context.close().catch(() => {});
    },
  };
}

/** The browser's own Dutch voice, when Ayla's voice does not come (iOS DeviceVoice). */
export function speakWithDeviceVoice(text: string) {
  return new Promise<void>((resolve) => {
    if (!('speechSynthesis' in window)) {
      resolve();
      return;
    }
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'nl-NL';
    utterance.onend = () => resolve();
    utterance.onerror = () => resolve();
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(utterance);
  });
}

export function stopDeviceVoice() {
  if ('speechSynthesis' in window) window.speechSynthesis.cancel();
}

interface BlipNote {
  frequency: number;
  at?: number;
  length?: number;
  volume?: number;
}

// Soft 8-bit blips that go with the pixel orb (iOS VoiceBlip): square waves with a quick fade, very quiet.
const BLIPS: Record<'listen' | 'think' | 'end', BlipNote[]> = {
  listen: [{ frequency: 659 }, { frequency: 988, at: 0.08 }],
  think: [
    { frequency: 784, volume: 0.7 },
    { frequency: 659, at: 0.07, volume: 0.6 },
    { frequency: 784, at: 0.14, volume: 0.5 },
  ],
  end: [{ frequency: 523 }, { frequency: 392, at: 0.1, length: 0.12 }],
};
const BLIP_VOLUME = 0.05;

export function playBlip(context: AudioContext, name: keyof typeof BLIPS) {
  for (const note of BLIPS[name]) {
    const start = context.currentTime + (note.at ?? 0);
    const length = note.length ?? 0.07;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = 'square';
    oscillator.frequency.value = note.frequency;
    gain.gain.setValueAtTime(0, start);
    gain.gain.linearRampToValueAtTime(BLIP_VOLUME * (note.volume ?? 1), start + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + length);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(start);
    oscillator.stop(start + length + 0.02);
  }
}

/** The loudness per frequency band (low to high, 0 to 1), for the ring of blocks around the orb. */
export function getBands(analyser: AnalyserNode, buffer: Uint8Array<ArrayBuffer>, count: number) {
  analyser.getByteFrequencyData(buffer);
  // Speech sits in the lower part of the spectrum; the rest stays empty.
  const usable = Math.floor(buffer.length * 0.4);
  const size = Math.max(1, Math.floor(usable / count));
  return Array.from({ length: count }, (_, band) => {
    let sum = 0;
    for (let index = band * size; index < (band + 1) * size; index += 1) sum += buffer[index] ?? 0;
    return sum / size / 255;
  });
}
