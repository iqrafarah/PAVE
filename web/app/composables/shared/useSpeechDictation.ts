import type {
  SpeechRecognitionConstructor,
  SpeechRecognitionEventLike,
  SpeechRecognitionLike,
} from '~/types/speech';

const DICTATION_LANGUAGE = 'nl-NL';
const PERMISSION_ERRORS = ['not-allowed', 'service-not-allowed'];
// The user stopped talking or pressed stop: not something to show as an error.
const QUIET_ERRORS = ['no-speech', 'aborted'];

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
    .join('');
}

/** Dictation into the text field with the browser's own speech recognition (Dutch). Nothing is sent by itself. */
export function useSpeechDictation(onTranscript: (text: string) => void) {
  const isSupported = ref(false);
  const isListening = ref(false);
  const error = ref<string | null>(null);
  let recognition: SpeechRecognitionLike | null = null;

  function createRecognition(Recognition: SpeechRecognitionConstructor) {
    const created = new Recognition();
    created.lang = DICTATION_LANGUAGE;
    created.continuous = true;
    created.interimResults = true;
    created.onresult = (event) => onTranscript(joinTranscript(event));
    created.onerror = (event) => {
      if (QUIET_ERRORS.includes(event.error)) return;
      // 'network' means the browser has no speech service (Brave, Arc, Firefox…); 'audio-capture' that no microphone works.
      console.warn('[dictation] speech recognition failed:', event.error);
      const isBlocked = PERMISSION_ERRORS.includes(event.error);
      error.value = isBlocked ? AYLA_MICROPHONE_BLOCKED : AYLA_SPEECH_UNAVAILABLE;
    };
    created.onend = () => {
      isListening.value = false;
    };
    return created;
  }

  // The browser asks for the microphone here, only after the user pressed the button.
  function start() {
    const Recognition = getRecognitionConstructor();
    if (!Recognition) return;

    error.value = null;
    recognition = createRecognition(Recognition);
    try {
      recognition.start();
      isListening.value = true;
    } catch {
      error.value = AYLA_SPEECH_UNAVAILABLE;
    }
  }

  function stop() {
    recognition?.stop();
    isListening.value = false;
  }

  onMounted(() => {
    isSupported.value = getRecognitionConstructor() !== null;
  });
  onBeforeUnmount(stop);

  return { isSupported, isListening, error, start, stop };
}
