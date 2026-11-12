<script setup lang="ts">
import type { VoiceState } from '~/composables/useAylaVoice';

// The screen around Ayla's orb while talking (iOS AylaAmbientField, from the voice demo): a soft glow, waves across
// a grid of small blocks (in while listening, diagonal while thinking, out while speaking, an odd twinkle when idle)
// and a ring of blocks around the orb that follows the voice like an equalizer (yours in sage, Ayla's in green).
const props = defineProps<{
  state: VoiceState;
  getLevel: () => number;
  getBands: () => number[];
  // The orb and the caption on screen, so the field stays around the orb and leaves the text readable.
  getOrb: () => DOMRect | null;
  getQuiet: () => DOMRect | null;
}>();

const MODES: VoiceState[] = ['off', 'listening', 'thinking', 'speaking'];
const REVEAL_SECONDS = 1.6;

const canvasRef = useTemplateRef<HTMLCanvasElement>('canvas');
const mix = [1, 0, 0, 0];
let smoothLevel = 0;
let lastTime: number | null = null;
let revealedAt: number | null = null;
let frame = 0;
let green = '53 94 75';
let sage = '95 143 119';

function step(perFrame: number, frames: number) {
  return 1 - Math.pow(1 - perFrame, frames);
}

function hash(i: number, j: number) {
  const x = Math.sin(i * 127.1 + j * 311.7) * 43758.5453;
  return x - Math.floor(x);
}

function toRgb(hex: string) {
  const value = Number.parseInt(hex.replace('#', ''), 16);
  return `${(value >> 16) & 255} ${(value >> 8) & 255} ${value & 255}`;
}

function draw(now: number) {
  frame = requestAnimationFrame(draw);
  const canvas = canvasRef.value;
  const context = canvas?.getContext('2d');
  const orb = props.getOrb();
  if (!canvas || !context || !orb) return;
  const bounds = canvas.getBoundingClientRect();
  const { width, height } = bounds;
  const scale = window.devicePixelRatio || 1;
  if (canvas.width !== Math.round(width * scale) || canvas.height !== Math.round(height * scale)) {
    canvas.width = Math.round(width * scale);
    canvas.height = Math.round(height * scale);
  }
  context.setTransform(scale, 0, 0, scale, 0, 0);
  context.clearRect(0, 0, width, height);

  const t = (now / 1000) % 10000;
  const frames = lastTime === null ? 1 : Math.min(((now - lastTime) / 1000) * 60, 3);
  lastTime = now;
  revealedAt ??= now;
  const modeIndex = Math.max(0, MODES.indexOf(props.state === 'starting' ? 'off' : props.state));
  for (let index = 0; index < mix.length; index += 1) {
    mix[index] = (mix[index] ?? 0) + ((modeIndex === index ? 1 : 0) - (mix[index] ?? 0)) * step(0.05, frames);
  }
  smoothLevel += (props.getLevel() - smoothLevel) * step(0.3, frames);
  const [idle = 0, listening = 0, thinking = 0, speaking = 0] = mix;

  const cx = orb.left + orb.width / 2 - bounds.left;
  const cy = orb.top + orb.height / 2 - bounds.top;
  const orbRadius = (orb.width / 2) * 0.86;
  const quietRect = props.getQuiet();
  const isQuiet = (x: number, y: number) =>
    quietRect !== null &&
    x > quietRect.left - bounds.left - 16 &&
    x < quietRect.right - bounds.left + 16 &&
    y > quietRect.top - bounds.top - 12 &&
    y < quietRect.bottom - bounds.top + 12;

  // It appears in a wave rolling out from the orb.
  const revealT = Math.min(1, (now - revealedAt) / 1000 / REVEAL_SECONDS);
  const reveal = 1 - Math.pow(1 - revealT, 3);

  // A soft green glow around the orb; brighter when active, pulsing with the voice.
  const glow =
    (listening * (0.08 + smoothLevel * 0.08) + thinking * 0.08 + speaking * (0.1 + smoothLevel * 0.14)) * reveal;
  if (glow > 0.003) {
    const gradient = context.createRadialGradient(cx, cy, orbRadius * 0.3, cx, cy, Math.max(width, height) * 0.6);
    gradient.addColorStop(0, `rgb(${green} / ${glow})`);
    gradient.addColorStop(1, `rgb(${green} / 0)`);
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, height);
  }

  // A block grid aligned on the orb's centre, so the rings stay round.
  const cell = width < 600 ? 18 : 24;
  const block = cell * 0.36;
  const reach = Math.hypot(Math.max(cx, width - cx), Math.max(cy, height - cy));
  const waveRadius = reveal * reach * 1.1;
  for (let i = -Math.ceil(cx / cell); i <= Math.ceil((width - cx) / cell); i += 1) {
    for (let j = -Math.ceil(cy / cell); j <= Math.ceil((height - cy) / cell); j += 1) {
      const x = cx + i * cell;
      const y = cy + j * cell;
      const d = Math.hypot(x - cx, y - cy);
      if (d < orbRadius * 1.6 || d > waveRadius || isQuiet(x, y)) continue;
      const h = hash(i, j);
      const far = d / reach;

      let alpha = revealT < 1 ? Math.max(0, 1 - Math.abs(d - waveRadius) / 70) * 0.45 * (0.5 + h * 0.5) : 0;
      alpha += idle * Math.max(0, Math.sin(t * 0.5 + h * 60) - 0.93) * 2.2;
      alpha += listening * Math.pow(Math.max(0, Math.sin(d / 70 + t * 3.2)), 10) * (0.08 + far * 0.3) * (0.6 + smoothLevel * 1.2);
      alpha += thinking * Math.pow(Math.max(0, Math.sin((x - cx + (y - cy)) / 140 + t * 3.5)), 12) * 0.3 * (0.6 + h * 0.4);
      alpha += speaking * Math.pow(Math.max(0, Math.sin(d / 55 - t * 6)), 8) * (0.06 + smoothLevel * 0.5) * (1 - far * 0.8);
      if (alpha < 0.01) continue;
      context.fillStyle = `rgb(${green} / ${Math.min(alpha, 0.55)})`;
      context.fillRect(x - block / 2, y - block / 2, block, block);
    }
  }

  // The equalizer ring: columns of blocks per frequency band, mirrored so the low tones sit at the top on both sides.
  const ringWeight = Math.max(listening, speaking) * reveal;
  const bands = props.getBands();
  if (ringWeight <= 0.02 || !bands.length) return;
  const segments = bands.length * 2;
  const swell = listening * (0.04 * Math.sin(t * 2.6) + smoothLevel * 0.08) + speaking * smoothLevel * 0.14;
  const ringStart = (orbRadius / 0.86) * (1.02 + swell);
  const color = speaking > listening ? green : sage;
  for (let k = 0; k < segments; k += 1) {
    const band = k < bands.length ? k : segments - 1 - k;
    const blocks = Math.min(8, Math.round((bands[band] ?? 0) * ringWeight * 10));
    const angle = -Math.PI / 2 + (k / segments) * Math.PI * 2;
    for (let b = 0; b < blocks; b += 1) {
      const r = ringStart + b * cell * 0.55;
      const x = Math.round(cx + Math.cos(angle) * r - block / 2);
      const y = Math.round(cy + Math.sin(angle) * r - block / 2);
      if (isQuiet(x + block / 2, y + block / 2)) continue;
      context.fillStyle = `rgb(${color} / ${0.8 - (b / 8) * 0.55})`;
      context.fillRect(x, y, block, block);
    }
  }
}

onMounted(() => {
  // People who asked for less motion get the orb without the moving field.
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const styles = getComputedStyle(document.documentElement);
  green = toRgb(styles.getPropertyValue('--color-orb-6').trim());
  sage = toRgb(styles.getPropertyValue('--color-orb-4').trim());
  frame = requestAnimationFrame(draw);
});
onBeforeUnmount(() => cancelAnimationFrame(frame));
</script>

<template>
  <canvas ref="canvas" class="pointer-events-none absolute inset-0 size-full" aria-hidden="true" />
</template>
