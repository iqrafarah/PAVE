import type {
  SpeechRecognitionConstructor,
  SpeechRecognitionEventLike,
  SpeechRecognitionLike,
} from '~/types/speech';

export type VoiceState = 'off' | 'starting' | 'listening' | 'thinking' | 'speaking';

interface VoiceSessionState {
  state: VoiceState;
  isMuted: boolean;
  // What Ayla heard so far in this turn.
  heard: string;
  // What Ayla is saying, for the captions.
  spokenText: string;
  speakingSince: number | null;
  usesDeviceVoice: boolean;
  problem: string | null;
}

// Browser objects cannot live in the shared state, and voice mode only runs in the browser.
let recognition: SpeechRecognitionLike | null = null;
let player: VoicePlayer | null = null;
let microphone: MediaStream | null = null;
let microphoneContext: AudioContext | null = null;
let microphoneAnalyser: AnalyserNode | null = null;
let microphoneBuffer: Float32Array<ArrayBuffer> | null = null;
let microphoneBands: Uint8Array<ArrayBuffer> | null = null;
let cues: VoiceCue[] = [];
const BAND_COUNT = 12;
let silenceTimer: ReturnType<typeof setTimeout> | undefined;
let speechController: AbortController | null = null;
let attempt = 0;

function getRecognitionConstructor(): SpeechRecognitionConstructor | null {
  const speechWindow = window as unknown as {
    SpeechRecognition?: SpeechRecognitionConstructor;
    webkitSpeechRecognition?: SpeechRecognitionConstructor;
  };
  return speechWindow.SpeechRecognition ?? speechWindow.webkitSpeechRecognition ?? null;
}

function joinTranscript(event: SpeechRecognitionEventLike) {
  return Array.from(event.results)
    .map((result) => result[0]?.transcript ?? '')
    .join('')
    .trim();
}

/**
 * A spoken conversation with Ayla, like voice mode on the iPhone (AylaVoiceSession.swift): Ayla listens, sends the
 * question after 1.2 seconds of silence, reads her answer out loud in her own voice and listens again, until the user
 * stops. Talking through Ayla interrupts her. Only text leaves the browser: the user's voice never does.
 */
export function useAylaVoice() {
  const session = useState<VoiceSessionState>('ayla-voice', () => ({
    state: 'off',
    isMuted: false,
    heard: '',
    spokenText: '',
    speakingSince: null,
    usesDeviceVoice: false,
    problem: null,
  }));
  // The orb large in the middle of the screen, or small above the text field with the conversation in view.
  const isCompact = useState('ayla-voice-compact', () => true);
  const conversation = useAylaConversation();
  const { streamSpeech, warmUp } = useAyla();

  const isActive = computed(() => session.value.state !== 'off');
  const isSupported = () => Boolean(getRecognitionConstructor()) && 'AudioContext' in window;

  function getMicrophoneLevel() {
    if (!microphoneAnalyser || !microphoneBuffer || session.value.isMuted) return 0;
    return getLevel(microphoneAnalyser, microphoneBuffer);
  }

  function getSpeakerLevel() {
    return player?.getLevel() ?? 0;
  }

  /** The loudness per frequency band of whoever is talking: the user while listening, Ayla while speaking. */
  function getVoiceBands() {
    if (session.value.state === 'speaking') return player?.getBands(BAND_COUNT) ?? [];
    if (session.value.state !== 'listening' || !microphoneAnalyser || !microphoneBands || session.value.isMuted) return [];
    return getBands(microphoneAnalyser, microphoneBands, BAND_COUNT);
  }

  /** The icon the orb forms right now, while Ayla talks about a part of PAVE. */
  function getIcon(now: number) {
    const { state, speakingSince, spokenText } = session.value;
    if (state !== 'speaking' || speakingSince === null) return null;
    return getVoiceIconAt(cues, spokenText.length, (now - speakingSince) / 1000);
  }

  function stopRecognizing() {
    if (!recognition) return;
    recognition.onend = null;
    recognition.onresult = null;
    recognition.onerror = null;
    try {
      recognition.abort ? recognition.abort() : recognition.stop();
    } catch {
      // It was not running.
    }
    recognition = null;
  }

  function startRecognizing() {
    stopRecognizing();
    const Recognition = getRecognitionConstructor();
    if (!Recognition || session.value.isMuted) return;
    const created = new Recognition();
    created.lang = 'nl-NL';
    created.continuous = true;
    created.interimResults = true;
    created.onresult = (event) => recognized(joinTranscript(event));
    created.onerror = (event) => {
      if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
        session.value.problem = VOICE_NOT_ALLOWED;
        stop();
      }
    };
    // The browser stops listening by itself after a while: send what was heard, or simply keep listening.
    created.onend = () => {
      if (recognition !== created) return;
      recognition = null;
      if (session.value.state === 'listening' && session.value.heard) endTurn();
      else if (session.value.state === 'listening' || session.value.state === 'speaking') startRecognizing();
    };
    recognition = created;
    try {
      created.start();
    } catch {
      recognition = null;
    }
  }

  function listen() {
    clearTimeout(silenceTimer);
    session.value.heard = '';
    session.value.speakingSince = null;
    session.value.spokenText = '';
    session.value.state = 'listening';
    startRecognizing();
  }

  function canBeInterruptedBy(text: string) {
    const since = session.value.speakingSince;
    if (session.value.usesDeviceVoice || since === null) return false;
    return Date.now() - since > VOICE_INTERRUPT_AFTER_MS && countWords(text) >= 2;
  }

  function stopSpeaking() {
    speechController?.abort();
    speechController = null;
    player?.stop();
    stopDeviceVoice();
  }

  function recognized(text: string) {
    if (session.value.state === 'speaking') {
      if (!canBeInterruptedBy(text)) return;
      stopSpeaking();
      session.value.state = 'listening';
      session.value.speakingSince = null;
    }
    if (session.value.state !== 'listening') return;
    session.value.heard = text;
    scheduleEndOfTurn();
  }

  function scheduleEndOfTurn() {
    clearTimeout(silenceTimer);
    if (session.value.isMuted) return;
    silenceTimer = setTimeout(endTurn, VOICE_END_OF_TURN_MS);
  }

  async function endTurn() {
    const question = session.value.heard.trim();
    if (session.value.state !== 'listening' || !question) return;
    clearTimeout(silenceTimer);
    stopRecognizing();
    session.value.state = 'thinking';
    player?.blip('think');
    const current = attempt;

    await conversation.send({
      text: question,
      input: 'voice',
      onConversationStarted: (id) => navigateTo(`/ayla/${id}`),
    });
    if (current !== attempt || session.value.state !== 'thinking') return;

    const last = conversation.state.value.messages.at(-1);
    const reply = last?.role === 'ayla' ? last.reply : null;
    if (!reply) {
      // Ayla could not answer: the error shows in the chat, as on the iPhone.
      stop();
      return;
    }
    await speak([reply.text, reply.question?.text].filter(Boolean).join(' '), current);
  }

  function beginSpeaking(text: string) {
    session.value.state = 'speaking';
    session.value.speakingSince = Date.now();
    session.value.spokenText = text;
    cues = getVoiceCues(text);
    // Listening again at once, so the user can talk through Ayla.
    startRecognizing();
  }

  async function speak(text: string, current: number) {
    session.value.usesDeviceVoice = false;
    speechController = new AbortController();
    const { signal } = speechController;
    // Ayla keeps thinking until her voice is really there; after 8 seconds the browser's voice reads it instead.
    const waitTimer = setTimeout(() => speechController?.abort(), VOICE_WAIT_MS);
    const stream = await streamSpeech(text, signal);
    let heardAny = false;
    if (stream && current === attempt) {
      heardAny = await player!.play(stream, () => {
        clearTimeout(waitTimer);
        beginSpeaking(text);
      });
    }
    clearTimeout(waitTimer);
    if (current !== attempt) return;
    if (!heardAny && session.value.state === 'thinking') {
      session.value.usesDeviceVoice = true;
      beginSpeaking(text);
      await speakWithDeviceVoice(text);
    }
    if (current === attempt && session.value.state === 'speaking') listen();
  }

  async function start() {
    if (isActive.value) return;
    if (!isSupported()) {
      session.value.problem = VOICE_UNAVAILABLE;
      return;
    }
    attempt += 1;
    const current = attempt;
    session.value = { ...session.value, state: 'starting', problem: null, heard: '', isMuted: false };
    // As in ChatGPT, talking starts with the orb above the text field and the conversation in view.
    isCompact.value = true;
    warmUp();
    try {
      // Echo cancellation keeps Ayla's own voice out of the microphone, so the user can interrupt her.
      microphone = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true },
      });
    } catch {
      if (current === attempt) {
        session.value.problem = VOICE_NOT_ALLOWED;
        session.value.state = 'off';
      }
      return;
    }
    if (current !== attempt) {
      microphone.getTracks().forEach((track) => track.stop());
      return;
    }
    microphoneContext = new AudioContext();
    microphoneAnalyser = microphoneContext.createAnalyser();
    microphoneAnalyser.fftSize = 512;
    microphoneBuffer = new Float32Array(microphoneAnalyser.fftSize);
    microphoneBands = new Uint8Array(microphoneAnalyser.frequencyBinCount);
    microphoneContext.createMediaStreamSource(microphone).connect(microphoneAnalyser);
    player = createVoicePlayer();
    player.blip('listen');
    listen();
  }

  function stop() {
    if (session.value.state === 'off') return;
    attempt += 1;
    clearTimeout(silenceTimer);
    stopRecognizing();
    stopSpeaking();
    player?.blip('end');
    const closing = player;
    // The closing blip still plays before the audio is let go.
    setTimeout(() => closing?.close(), 400);
    player = null;
    microphone?.getTracks().forEach((track) => track.stop());
    microphone = null;
    microphoneContext?.close().catch(() => {});
    microphoneContext = null;
    microphoneAnalyser = null;
    session.value = { ...session.value, state: 'off', isMuted: false, heard: '', spokenText: '', speakingSince: null };
  }

  function toggleMute() {
    session.value.isMuted = !session.value.isMuted;
    microphone?.getAudioTracks().forEach((track) => (track.enabled = !session.value.isMuted));
    if (session.value.isMuted) {
      clearTimeout(silenceTimer);
      stopRecognizing();
    } else if (session.value.state === 'listening' || session.value.state === 'speaking') {
      startRecognizing();
    }
  }

  /** Clicking the orb: while Ayla thinks or talks it stops her and listens; while listening it sends at once. */
  function tapOrb() {
    const { state, heard } = session.value;
    if (state === 'listening' && heard) endTurn();
    else if (state === 'thinking' || state === 'speaking') {
      attempt += 1;
      conversation.stop();
      stopSpeaking();
      listen();
    }
  }

  /** A typed question during the conversation: Ayla answers it out loud, like a spoken one. */
  function sendTyped(text: string) {
    const question = text.trim();
    if (!isActive.value || session.value.state === 'starting' || !question) return;
    attempt += 1;
    conversation.stop();
    stopSpeaking();
    session.value.heard = question;
    session.value.state = 'listening';
    endTurn();
  }

  /**
   * The sentence Ayla is saying at `now`, or null when she is not speaking. The voice gives no timings, so the place in
   * the text is estimated from how long she has been talking (iOS AylaVoiceSession.spokenSentence).
   */
  function getSpokenSentence(now: number) {
    const { state, spokenText, speakingSince } = session.value;
    if (state !== 'speaking' || !spokenText || speakingSince === null) return null;
    const position = Math.floor(((now - speakingSince) / 1000) * VOICE_CHARACTERS_PER_SECOND);
    return getSentenceAt(spokenText, position);
  }

  /** The line under the orb: what you say, the sentence Ayla is saying, or a hint (iOS stageCaption). */
  function getCaption(now: number) {
    const { state, heard, isMuted } = session.value;
    if (heard) return { text: heard, kind: 'heard' as const };
    const spokenSentence = getSpokenSentence(now);
    if (spokenSentence !== null) return { text: spokenSentence, kind: 'answer' as const };
    if (state === 'thinking') return { text: VOICE_THINKING, kind: 'status' as const };
    if (isMuted) return { text: VOICE_MUTED_HINT, kind: 'status' as const };
    if (state === 'starting') return { text: VOICE_STARTING, kind: 'status' as const };
    if (state === 'listening' && conversation.state.value.messages.length) {
      return { text: VOICE_LISTENING, kind: 'status' as const };
    }
    return { text: VOICE_HINT, kind: 'status' as const };
  }

  return {
    session,
    isCompact,
    isActive,
    isSupported,
    start,
    stop,
    toggleMute,
    tapOrb,
    sendTyped,
    getCaption,
    getSpokenSentence,
    getMicrophoneLevel,
    getSpeakerLevel,
    getVoiceBands,
    getIcon,
  };
}
