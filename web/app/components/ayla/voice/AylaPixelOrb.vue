<script setup lang="ts">
import type { VoiceState } from '~/composables/ayla/useAylaVoice';
import type { VoiceIconName } from '~/utils/ayla/aylaVoiceIcons';

// Ayla's orb from the voice demo, as on the iPhone (AylaPixelOrb.swift): a round field of square pixel blocks in
// PAVE greens. Each state moves the blocks differently, driven by how loud the user (listening) or Ayla (speaking) is.
// While Ayla talks about part of PAVE, the blocks briefly form its icon and then flow back into the orb.
const props = defineProps<{
  state: VoiceState;
  getLevel: () => number;
  getIcon?: () => VoiceIconName | null;
}>();

const CELLS = 23;
const MODES: VoiceState[] = ['off', 'listening', 'thinking', 'speaking'];

const canvasRef = useTemplateRef<HTMLCanvasElement>('canvas');
const mix = [1, 0, 0, 0];
let palette: string[] = [];
let smoothLevel = 0;
let listenPhase = 0;
let iconMix = 0;
let shownIcon: VoiceIconName | null = null;
let lastTime: number | null = null;
let frame = 0;
let reduceMotion = false;

// The demo smooths per frame at 60 frames per second; screens draw faster or slower, so it is scaled by time.
function step(perFrame: number, dt: number) {
  return 1 - Math.pow(1 - perFrame, dt * 60);
}

function hash(i: number, j: number) {
  const x = Math.sin(i * 12.9898 + j * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

function draw(now: number) {
  const canvas = canvasRef.value;
  const context = canvas?.getContext('2d');
  if (!canvas || !context) return;
  const side = canvas.clientWidth;
  const scale = window.devicePixelRatio || 1;
  if (canvas.width !== Math.round(side * scale)) {
    canvas.width = Math.round(side * scale);
    canvas.height = Math.round(side * scale);
  }
  context.setTransform(scale, 0, 0, scale, 0, 0);
  context.clearRect(0, 0, side, side);

  const t = reduceMotion ? 0 : (now / 1000) % 10000;
  const dt = lastTime === null ? 0 : Math.min((now - lastTime) / 1000, 0.1);
  lastTime = now;
  const modeIndex = Math.max(0, MODES.indexOf(props.state === 'starting' ? 'off' : props.state));
  for (let index = 0; index < mix.length; index += 1) {
    mix[index] = (mix[index] ?? 0) + ((modeIndex === index ? 1 : 0) - (mix[index] ?? 0)) * step(0.08, dt);
  }
  const level = props.state === 'listening' || props.state === 'speaking' ? props.getLevel() : 0;
  smoothLevel += (level - smoothLevel) * step(0.35, dt);
  if (!reduceMotion) listenPhase += dt * (4.5 + smoothLevel * 6);

  const icon = props.getIcon?.() ?? null;
  if (icon) shownIcon = icon;
  iconMix += ((icon ? 1 : 0) - iconMix) * (reduceMotion ? 1 : step(0.12, dt));
  if (iconMix < 0.01 && !icon) shownIcon = null;
  const iconRows = shownIcon ? VOICE_ICON_ROWS[shownIcon] : null;
  // The hand waves.
  const wave = shownIcon === 'hand' && !reduceMotion ? Math.round(Math.sin(t * 7)) : 0;

  const [idle = 0, listening = 0, thinking = 0, speaking = 0] = mix;
  const cell = side / CELLS;
  const gap = Math.max(1, cell * 0.16);
  const center = (CELLS - 1) / 2;
  // The outline breathes while listening and leans in when the user talks, and swells with Ayla's voice.
  const radius =
    0.86 +
    listening * (0.04 * Math.sin(t * 2.6) + smoothLevel * 0.08) +
    thinking * 0.03 * Math.sin(t * 5) +
    speaking * smoothLevel * 0.14;

  for (let i = 0; i < CELLS; i += 1) {
    for (let j = 0; j < CELLS; j += 1) {
      const x = (i - center) / center;
      const y = (j - center) / center;
      const r = Math.sqrt(x * x + y * y);
      const h = hash(i, j);
      // A ragged, slowly flickering edge, so the circle feels alive.
      const edge = radius + (h - 0.5) * 0.14 + 0.04 * Math.sin(t * 1.3 + h * 20);
      if (r > edge) continue;

      // Darker towards the lower left, like Ayla's slash.
      let v = 0.62 - r * 0.35 + (y - x) * 0.12;
      v += idle * 0.16 * Math.sin(t * 1.1 + h * Math.PI * 2);
      v += listening * (0.22 + smoothLevel * 0.4) * Math.sin(r * 9 + listenPhase);
      v += thinking * 0.4 * Math.sin((x + y) * 4 + t * 7);
      v += speaking * (0.15 + smoothLevel * 0.55) * Math.sin(r * 11 - t * 11);
      v += speaking * smoothLevel * 0.25 * (1 - r);
      // An icon assembles block by block: dark in the icon, very light around it.
      if (iconRows) {
        const offset = (CELLS - iconRows.length) / 2;
        const isInIcon = iconRows[j - offset]?.[i - offset - wave] === '#';
        const local = Math.min(1, Math.max(0, iconMix * 1.6 - h * 0.6));
        v += ((isInIcon ? 1 : 0.05) - v) * local;
      }
      v = Math.min(1, Math.max(0, v));

      const shade = Math.min(palette.length - 1, Math.floor(v * palette.length));
      context.globalAlpha = Math.min(1, Math.max(0.25, (edge - r) * 7));
      context.fillStyle = palette[shade] ?? '#355d4c';
      context.fillRect(i * cell + gap / 2, j * cell + gap / 2, cell - gap, cell - gap);
    }
  }
  context.globalAlpha = 1;
  if (!reduceMotion) frame = requestAnimationFrame(draw);
}

useThemeColors((styles) => {
  palette = Array.from({ length: 7 }, (_, index) => styles.getPropertyValue(`--color-orb-${index}`).trim());
  if (reduceMotion) draw(performance.now());
});

onMounted(() => {
  reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  frame = requestAnimationFrame(draw);
});
onBeforeUnmount(() => cancelAnimationFrame(frame));
</script>

<template>
  <canvas ref="canvas" class="aspect-square w-full" aria-hidden="true" />
</template>
