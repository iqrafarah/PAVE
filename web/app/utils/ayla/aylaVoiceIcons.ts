// The 13 x 13 pixel icons Ayla's orb forms while she talks about part of PAVE (iOS AylaPixelIcons.swift, from the
// voice demo). "#" is a block.
export const VOICE_ICON_ROWS = {
  hand: [
    '......#......',
    '....#.#.#....',
    '....#.#.#.#..',
    '....#.#.#.#..',
    '....#.#.#.#..',
    '....#######..',
    '#...#######..',
    '##..#######..',
    '.##.#######..',
    '..#########..',
    '...#######...',
    '....#####....',
    '....#####....',
  ],
  ayla: [
    '.............',
    '.........###.',
    '.........###.',
    '.........###.',
    '.......###...',
    '.......###...',
    '.....###.....',
    '.....###.....',
    '...###.......',
    '...###.......',
    '.###.........',
    '.###.........',
    '.###.........',
  ],
  slot: [
    '....#####....',
    '...##...##...',
    '...#.....#...',
    '...#.....#...',
    '...#.....#...',
    '.###########.',
    '.###########.',
    '.#####.#####.',
    '.####...####.',
    '.#####.#####.',
    '.#####.#####.',
    '.###########.',
    '.###########.',
  ],
  toestemming: [
    '.............',
    '.............',
    '..........###',
    '.........###.',
    '........###..',
    '.......###...',
    '###...###....',
    '.###.###.....',
    '..#####......',
    '...###.......',
    '....#........',
    '.............',
    '.............',
  ],
  tijdelijk: [
    '#############',
    '.#.........#.',
    '..#.......#..',
    '...#.###.#...',
    '....#.#.#....',
    '.....#.#.....',
    '......#......',
    '.....#.#.....',
    '....#...#....',
    '...#..#..#...',
    '..#..###..#..',
    '.#.#######.#.',
    '#############',
  ],
  kluis: [
    '.###########.',
    '#...........#',
    '#.#########.#',
    '#.#.......#.#',
    '#.#..###..#.#',
    '#.#.#...#.#.#',
    '#.#.#.#.#.###',
    '#.#.#...#.#.#',
    '#.#..###..#.#',
    '#.#.......#.#',
    '#.#########.#',
    '#...........#',
    '.##.......##.',
  ],
  plan: [
    '........#....',
    '........###..',
    '........####.',
    '........#....',
    '........#....',
    '......###....',
    '......#......',
    '....###......',
    '....#........',
    '..###........',
    '..#..........',
    '###..........',
    '###..........',
  ],
  profiel: [
    '....#####....',
    '...#######...',
    '...#######...',
    '...#######...',
    '...#######...',
    '....#####....',
    '.............',
    '...#######...',
    '.###########.',
    '#############',
    '#############',
    '#############',
    '#############',
  ],
  cv: [
    '.########....',
    '.#......##...',
    '.#......#.#..',
    '.#......####.',
    '.#.........#.',
    '.#.######..#.',
    '.#.........#.',
    '.#.#######.#.',
    '.#.........#.',
    '.#.#######.#.',
    '.#.........#.',
    '.#.####....#.',
    '.###########.',
  ],
  werk: [
    '.............',
    '....#####....',
    '....#...#....',
    '.###########.',
    '#############',
    '#############',
    '#############',
    '.....###.....',
    '#############',
    '#############',
    '#############',
    '.###########.',
    '.............',
  ],
  opleiding: [
    '.............',
    '.###.....###.',
    '#...##.##...#',
    '#.....#.....#',
    '#.###.#.###.#',
    '#.....#.....#',
    '#.###.#.###.#',
    '#.....#.....#',
    '#.###.#.###.#',
    '#.....#.....#',
    '#####.#.#####',
    '.....###.....',
    '.............',
  ],
  vaardigheden: [
    '......#......',
    '......#......',
    '.....###.....',
    '.....###.....',
    '#############',
    '.###########.',
    '..#########..',
    '...#######...',
    '...#######...',
    '..####.####..',
    '..###...###..',
    '.##.......##.',
    '.#.........#.',
  ],
} as const;

export type VoiceIconName = keyof typeof VOICE_ICON_ROWS;

export interface VoiceCue {
  // Where in the answer the icon shows, from 0 (start) to 1 (end).
  at: number;
  icon: VoiceIconName;
}

// The words that bring up an icon, as on the iPhone (PAVECore AylaVoiceCue.words).
const CUE_WORDS: [VoiceIconName, RegExp][] = [
  ['hand', /^\s*(hoi|hallo|hey|hee|goedemorgen|goedemiddag|goedenavond)\b|\b(doei|tot ziens)\b/gi],
  ['ayla', /\bayla\b/gi],
  ['slot', /\b(privacy|veilig\w*|beveilig\w*|afgeschermd|beschermd|gevoelige)\b/gi],
  ['toestemming', /\b(toestemming|akkoord|beslist|beslis\w*|regie)\b/gi],
  ['tijdelijk', /\b(tijdelijk\w*|intrek\w*|ingetrokken)\b/gi],
  ['kluis', /\bkluis\w*/gi],
  ['plan', /\b(plan|plannen|stappenplan|doel|doelen)\b/gi],
  ['profiel', /\bprofiel\w*/gi],
  ['cv', /\b(cv|cv's|sollicit\w*|motivatiebrief\w*)\b/gi],
  ['werk', /\b(vacature\w*|werkgever\w*|baan|banen|werkervaring|stage\w*)\b/gi],
  ['opleiding', /\b(opleiding\w*|diploma\w*|studie\w*|vmbo|mbo|hbo|universiteit)\b/gi],
  ['vaardigheden', /\b(vaardighe\w*|soft skills|talent\w*|sterke punten)\b/gi],
];
// Two icons are at least this far apart (as a share of the answer), so the orb never flickers.
const MINIMUM_CUE_GAP = 0.18;
/** How long an icon stays in the orb. */
export const VOICE_ICON_SECONDS = 2;

/** The icons for an answer, in order of appearance. */
export function getVoiceCues(text: string): VoiceCue[] {
  if (!text) return [];
  const found: VoiceCue[] = [];
  for (const [icon, pattern] of CUE_WORDS) {
    for (const match of text.matchAll(pattern)) found.push({ at: (match.index ?? 0) / text.length, icon });
  }
  const cues: VoiceCue[] = [];
  for (const cue of found.sort((first, second) => first.at - second.at)) {
    const last = cues.at(-1);
    if (last && (cue.icon === last.icon || cue.at - last.at < MINIMUM_CUE_GAP)) continue;
    cues.push(cue);
  }
  return cues;
}

/** The icon the orb shows `elapsedSeconds` into an answer of `textLength` characters. */
export function getVoiceIconAt(cues: VoiceCue[], textLength: number, elapsedSeconds: number): VoiceIconName | null {
  const duration = Math.max(1, textLength / VOICE_CHARACTERS_PER_SECOND);
  const shown = cues.findLast((cue) => {
    const shownAt = cue.at * duration;
    return elapsedSeconds >= shownAt && elapsedSeconds < shownAt + VOICE_ICON_SECONDS;
  });
  return shown?.icon ?? null;
}
