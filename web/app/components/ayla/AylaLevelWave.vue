<script setup lang="ts">
// A live sound wave of pixel blocks while you dictate (iOS PixelLevelWave): every bar is a moment, the newest on the
// right, and louder means taller.
const props = defineProps<{
  getLevel: () => number;
}>();

const BARS = 24;
const BLOCK = 3;
const GAP = 1.5;
const SAMPLE_EVERY_MS = 80;

const canvasRef = useTemplateRef<HTMLCanvasElement>('canvas');
let levels: number[] = [];
let lastSample = 0;
let frame = 0;
let loud = '#355d4c';
let quiet = '#b4d2c0';

function draw(now: number) {
  frame = requestAnimationFrame(draw);
  const canvas = canvasRef.value;
  const context = canvas?.getContext('2d');
  if (!canvas || !context) return;
  if (now - lastSample >= SAMPLE_EVERY_MS) {
    lastSample = now;
    levels = [...levels, props.getLevel()].slice(-BARS);
  }
  const { clientWidth: width, clientHeight: height } = canvas;
  const scale = window.devicePixelRatio || 1;
  if (canvas.width !== Math.round(width * scale)) {
    canvas.width = Math.round(width * scale);
    canvas.height = Math.round(height * scale);
  }
  context.setTransform(scale, 0, 0, scale, 0, 0);
  context.clearRect(0, 0, width, height);
  const maxBlocks = Math.max(1, Math.floor((height + GAP) / (BLOCK + GAP)));
  const barWidth = width / BARS;
  const start = BARS - levels.length;
  levels.forEach((level, offset) => {
    const blocks = Math.max(1, Math.min(maxBlocks, Math.ceil(level * maxBlocks * 1.5)));
    const x = (start + offset) * barWidth + (barWidth - BLOCK) / 2;
    let y = (height - (blocks * BLOCK + (blocks - 1) * GAP)) / 2;
    context.fillStyle = blocks > 1 ? loud : quiet;
    for (let block = 0; block < blocks; block += 1) {
      context.fillRect(x, y, BLOCK, BLOCK);
      y += BLOCK + GAP;
    }
  });
}

useThemeColors((styles) => {
  loud = styles.getPropertyValue('--color-brand').trim() || loud;
  quiet = styles.getPropertyValue('--color-orb-2').trim() || quiet;
});

onMounted(() => {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  frame = requestAnimationFrame(draw);
});
onBeforeUnmount(() => cancelAnimationFrame(frame));
</script>

<template>
  <canvas ref="canvas" class="h-5.5 min-w-0 flex-1" aria-hidden="true" />
</template>
