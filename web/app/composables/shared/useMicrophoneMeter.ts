/**
 * How loud the microphone is, for the sound wave while dictating. The sound itself goes nowhere: it is only measured.
 * If the microphone is not allowed the level simply stays 0.
 */
export function useMicrophoneMeter() {
  let stream: MediaStream | null = null;
  let context: AudioContext | null = null;
  let analyser: AnalyserNode | null = null;
  let buffer: Float32Array<ArrayBuffer> | null = null;

  async function start() {
    stop();
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch {
      return;
    }
    context = new AudioContext();
    analyser = context.createAnalyser();
    analyser.fftSize = 512;
    buffer = new Float32Array(analyser.fftSize);
    context.createMediaStreamSource(stream).connect(analyser);
  }

  function stop() {
    stream?.getTracks().forEach((track) => track.stop());
    context?.close().catch(() => {});
    stream = null;
    context = null;
    analyser = null;
  }

  function getMicrophoneLevel() {
    return analyser && buffer ? getLevel(analyser, buffer) : 0;
  }

  onBeforeUnmount(stop);

  return { start, stop, getMicrophoneLevel };
}
