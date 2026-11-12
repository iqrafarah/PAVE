// The welcome title typing out, with the same timing as iOS (AylaTypingTitle.swift).
export const TYPING_MARK_COUNT = 5;
const SECONDS_PER_CHARACTER = 0.065;
const BLINK_SECONDS = 0.7;
const HAND_OVER_SECONDS = 0.55;
const SQUARE_FADE_SECONDS = 0.1;
const BLINK_PHASES = 4;
const CURSOR_OUT_STEP = 0.05;
const FRONT_IN_DELAY = 0.12;
const FRONT_IN_STEP = 0.065;

export interface TypingMoment {
  shownCount: number;
  // How visible each cursor square is (bottom first), or null when there is no cursor.
  cursor: number[] | null;
  // The slash in front of the title, building up from the bottom.
  front: number[];
}

const ALL_ON = Array.from({ length: TYPING_MARK_COUNT }, () => 1);
const ALL_OFF = Array.from({ length: TYPING_MARK_COUNT }, () => 0);

function squareProgress(time: number) {
  return Math.min(1, Math.max(0, time / SQUARE_FADE_SECONDS));
}

export function getTypingDuration(characterCount: number) {
  return characterCount * SECONDS_PER_CHARACTER + BLINK_SECONDS + HAND_OVER_SECONDS;
}

export function getFinishedTyping(characterCount: number): TypingMoment {
  return { shownCount: characterCount, cursor: null, front: ALL_ON };
}

/** What the title shows `elapsed` seconds after typing started. */
export function getTypingMoment(characterCount: number, elapsed: number): TypingMoment {
  const typingSeconds = characterCount * SECONDS_PER_CHARACTER;
  if (elapsed < typingSeconds) {
    return { shownCount: Math.ceil(elapsed / SECONDS_PER_CHARACTER), cursor: ALL_ON, front: ALL_OFF };
  }

  const afterTyping = elapsed - typingSeconds;
  if (afterTyping < BLINK_SECONDS) {
    // Off, on, off, on: two blinks.
    const isOn = Math.floor(afterTyping / (BLINK_SECONDS / BLINK_PHASES)) % 2 === 1;
    return { shownCount: characterCount, cursor: isOn ? ALL_ON : null, front: ALL_OFF };
  }

  const time = afterTyping - BLINK_SECONDS;
  if (time >= HAND_OVER_SECONDS) return getFinishedTyping(characterCount);
  const indexes = Array.from({ length: TYPING_MARK_COUNT }, (_, index) => index);
  return {
    shownCount: characterCount,
    // Out from the top at the end of the title...
    cursor: indexes.map((index) => 1 - squareProgress(time - (TYPING_MARK_COUNT - 1 - index) * CURSOR_OUT_STEP)),
    // ...and in from the bottom in front of it.
    front: indexes.map((index) => squareProgress(time - FRONT_IN_DELAY - index * FRONT_IN_STEP)),
  };
}
