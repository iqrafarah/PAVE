/** True when animations should not run: the user switched them off in the settings, or asked for it in the system. */
export function isMotionReduced(): boolean {
  if (!import.meta.client) return false;
  return document.documentElement.dataset.reduceMotion === 'true'
    || window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}
