// At most a thirtieth of a second per frame, as AylaTypingClock on iOS: when the browser is briefly busy, the
// animation waits instead of skipping ahead.
const MAX_FRAME_SECONDS = 1 / 30;
const MS_PER_SECOND = 1000;

/** Seconds since start, counted per drawn frame. Stays at 0 when the user asks for reduced motion. */
export function useAnimationClock(options: { isRunning?: () => boolean } = {}) {
  const seconds = ref(0);
  const prefersReducedMotion = ref(false);
  let frameId = 0;
  let lastTime: number | null = null;

  function tick(time: number) {
    if (lastTime !== null) {
      const step = (time - lastTime) / MS_PER_SECOND;
      seconds.value += Math.min(Math.max(0, step), MAX_FRAME_SECONDS);
    }
    lastTime = time;
    const keepsRunning = options.isRunning?.() ?? true;
    if (keepsRunning) frameId = requestAnimationFrame(tick);
  }

  function start() {
    cancelAnimationFrame(frameId);
    seconds.value = 0;
    lastTime = null;
    if (prefersReducedMotion.value) return;
    frameId = requestAnimationFrame(tick);
  }

  function stop() {
    cancelAnimationFrame(frameId);
  }

  onMounted(() => {
    prefersReducedMotion.value = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  });
  onBeforeUnmount(stop);

  return { seconds, prefersReducedMotion, start, stop };
}
