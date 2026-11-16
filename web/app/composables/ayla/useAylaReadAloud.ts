// Lives outside the state: audio objects cannot be serialised, and reading aloud only happens in the browser.
let player: VoicePlayer | null = null;
let controller: AbortController | null = null;

/**
 * Reads one of Ayla's answers out loud in her own voice (iOS AylaReadAloud). Without her voice it uses the browser's
 * Dutch voice, so the button always does something.
 */
export function useAylaReadAloud() {
  const playingId = useState<string | null>('ayla-read-aloud', () => null);
  const { streamSpeech } = useAyla();

  function stop() {
    controller?.abort();
    controller = null;
    player?.stop();
    stopDeviceVoice();
    playingId.value = null;
  }

  async function toggle(id: string, text: string) {
    if (playingId.value === id) {
      stop();
      return;
    }
    stop();
    playingId.value = id;
    controller = new AbortController();
    player ??= createVoicePlayer();
    const stream = await streamSpeech(text, controller.signal);
    if (playingId.value !== id) return;
    const isPlayed = stream ? await player.play(stream, () => {}) : false;
    if (playingId.value !== id) return;
    if (!isPlayed) await speakWithDeviceVoice(text);
    if (playingId.value === id) playingId.value = null;
  }

  return { playingId, toggle, stop };
}
