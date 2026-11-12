// The pixel blocks of Ayla's status, copied from iOS (AylaThinkingBlocks.swift and AylaFallenBlocks.swift) so both
// apps move the same.

export interface BlockPoint {
  x: number;
  y: number;
}

export const THINKING_BLOCK_SIZE = 11.6;
export const THINKING_FRAME = { width: 99.13, height: 58 };
export const THINKING_LOOP_SECONDS = 7.052;
// What the blocks show when the user asks for reduced motion (iOS: progress 0.7).
export const THINKING_STILL_PROGRESS = 0.7;

export const THINKING_BLOCKS: BlockPoint[] = [
  { x: 0, y: 46.4 }, { x: 4.75, y: 34.8 },
  { x: 20.56, y: 46.4 }, { x: 26.36, y: 34.8 }, { x: 32.16, y: 23.2 },
  { x: 41.13, y: 46.4 }, { x: 46.93, y: 34.8 }, { x: 52.73, y: 23.2 }, { x: 58.53, y: 11.6 },
  { x: 64.33, y: 46.4 }, { x: 70.13, y: 34.8 }, { x: 75.93, y: 23.2 }, { x: 81.73, y: 11.6 }, { x: 87.53, y: 0 },
];

const FADE_IN_STEP = 0.04963;
const FADE_IN_LENGTH = 0.0575;
// When the last four blocks fade out again, as a fraction of the loop (start, end).
const FADE_OUTS: Record<number, [number, number]> = {
  10: [0.96755, 1.0],
  11: [0.90664, 0.97584],
  12: [0.84411, 0.91208],
  13: [0.78444, 0.84825],
};

/** How visible block `index` is at `progress` (0..1) in the loop. */
export function getThinkingOpacity(index: number, progress: number) {
  const fadeInStart = index * FADE_IN_STEP;
  const fadeIn = Math.min(Math.max((progress - fadeInStart) / FADE_IN_LENGTH, 0), 1);
  const fadeOut = FADE_OUTS[index];
  if (!fadeOut || progress <= fadeOut[0]) return fadeIn;

  const [start, end] = fadeOut;
  return fadeIn * (1 - Math.min((progress - start) / (end - start), 1));
}

export interface FallingBlock {
  origin: BlockPoint;
  fall: BlockPoint;
  // Radians, around the middle of the block.
  rotation: number;
}

export const FALLEN_BLOCK_SIZE = 11.936;
export const FALLEN_FRAME = { width: 102, height: 60 };
export const FALL_SECONDS = 0.415;

const STILL: BlockPoint = { x: 0, y: 0 };

export const FALLING_BLOCKS: FallingBlock[] = [
  { origin: { x: 0, y: 47.74 }, fall: STILL, rotation: 0 },
  { origin: { x: 4.88, y: 35.81 }, fall: { x: 6.35, y: 6.42 }, rotation: 0.5448 },
  { origin: { x: 21.16, y: 47.74 }, fall: STILL, rotation: 0 },
  { origin: { x: 27.13, y: 35.81 }, fall: { x: 3.33, y: 4.65 }, rotation: 0.7368 },
  { origin: { x: 33.1, y: 23.87 }, fall: { x: 8.66, y: 10.89 }, rotation: 0.3718 },
  { origin: { x: 42.32, y: 47.74 }, fall: STILL, rotation: 0 },
  { origin: { x: 48.29, y: 35.81 }, fall: { x: 5.46, y: 5.93 }, rotation: 0.3665 },
  { origin: { x: 54.26, y: 23.87 }, fall: { x: 5.74, y: 7.13 }, rotation: 0 },
  { origin: { x: 60.22, y: 11.94 }, fall: { x: -13.22, y: 10.07 }, rotation: -0.4506 },
  { origin: { x: 66.19, y: 47.74 }, fall: STILL, rotation: 0 },
  { origin: { x: 72.16, y: 35.81 }, fall: { x: 6.24, y: 9.59 }, rotation: 0.6563 },
  { origin: { x: 78.13, y: 23.87 }, fall: { x: -6.51, y: 9.75 }, rotation: -0.3327 },
  { origin: { x: 84.1, y: 11.94 }, fall: { x: 9.89, y: 31.05 }, rotation: 0.7247 },
  { origin: { x: 90.06, y: 0 }, fall: { x: -5.06, y: 32 }, rotation: 0 },
];

const DEGREES_PER_RADIAN = 180 / Math.PI;

/** The SVG transform of a falling block, `amount` 0 (standing) to 1 (fallen). */
export function getFallTransform(block: FallingBlock, amount: number) {
  const x = block.origin.x + block.fall.x * amount;
  const y = block.origin.y + block.fall.y * amount;
  const degrees = block.rotation * DEGREES_PER_RADIAN * amount;
  const middle = FALLEN_BLOCK_SIZE / 2;
  return `translate(${x} ${y}) rotate(${degrees} ${middle} ${middle})`;
}
