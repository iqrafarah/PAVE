// Voice mode, as on the iPhone (ios/PAVE/Features/Ayla/Voice). Texts word for word from AylaChatScreen.swift.
export const VOICE_SAMPLE_RATE = 24000;
/** Silence after which a spoken question is sent (iOS AylaVoiceSession.endOfTurn). */
export const VOICE_END_OF_TURN_MS = 1200;
/** Ayla only lets herself be interrupted after this long, and by at least two words, so a cough does not stop her. */
export const VOICE_INTERRUPT_AFTER_MS = 800;
/** How long Ayla's own voice may take to start before the browser's voice reads the answer instead. */
export const VOICE_WAIT_MS = 8000;
/** The voice says about this many characters per second; used for the captions. */
export const VOICE_CHARACTERS_PER_SECOND = 15;
/** The most text `ayla-voice` reads in one go. */
export const MAX_SPEECH_LENGTH = 2000;

export const VOICE_TALK = 'Praat met Ayla';
export const VOICE_STOP = 'Gesprek stoppen';
export const VOICE_MUTE = 'Microfoon uitzetten';
export const VOICE_UNMUTE = 'Microfoon aanzetten';
export const VOICE_THINKING = 'Ayla denkt na…';
export const VOICE_LISTENING = 'Ayla luistert…';
export const VOICE_STARTING = 'Microfoon aanzetten…';
export const VOICE_MUTED_HINT = 'Je microfoon staat uit. Klik op de microfoon om verder te praten.';
export const VOICE_HINT = 'Ik luister. Vraag me bijvoorbeeld welke banen bij je passen of hoe je je cv sterker maakt.';
export const VOICE_NOT_ALLOWED = 'Geef PAVE toegang tot je microfoon om met Ayla te praten.';
export const VOICE_UNAVAILABLE = 'Praten met Ayla werkt niet in deze browser. Typ je vraag maar.';
export const VOICE_SHOW_CHAT = 'Gesprek tonen';
export const VOICE_SHOW_ORB = 'Orb groot tonen';
export const READ_ALOUD = 'Voorlezen';
export const READ_ALOUD_STOP = 'Stop met voorlezen';

/** Turns pcm16 pieces into samples; a sample can be split over two pieces, so the odd byte waits for the next one. */
export function createPcm16Decoder() {
  let leftover: number | null = null;
  return (piece: Uint8Array) => {
    const bytes = leftover === null ? piece : Uint8Array.of(leftover, ...piece);
    const usable = bytes.length - (bytes.length % 2);
    leftover = bytes.length % 2 ? (bytes[bytes.length - 1] ?? null) : null;
    const view = new DataView(bytes.buffer, bytes.byteOffset, usable);
    const samples = new Float32Array(usable / 2);
    for (let index = 0; index < samples.length; index += 1) samples[index] = view.getInt16(index * 2, true) / 32768;
    return samples;
  };
}

/** The sentence of `text` that is being said at character `position`, for the caption under the orb. */
export function getSentenceAt(text: string, position: number) {
  const sentences = text.match(/[^.!?]+[.!?]*\s*/g) ?? [text];
  let end = 0;
  for (const sentence of sentences) {
    end += sentence.length;
    if (position < end) return sentence.trim();
  }
  return sentences.at(-1)?.trim() ?? '';
}

export function countWords(text: string) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

// Dictation (iOS AylaDictationBar)
export const DICTATION_LISTENING = 'Ik luister…';
export const DICTATION_CANCEL = 'Opname weggooien';
export const DICTATION_DONE = 'Klaar, tekst bewaren';
