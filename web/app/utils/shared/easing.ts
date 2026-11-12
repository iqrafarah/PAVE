const NEWTON_STEPS = 8;

/**
 * A CSS-style cubic-bezier easing (x1, y1, x2, y2) as a function of progress 0..1, for animations driven from
 * script, such as SVG attributes. Same curve as SwiftUI's timingCurve on iOS.
 */
export function cubicBezier(x1: number, y1: number, x2: number, y2: number) {
  const curve = (a: number, b: number, t: number) => 3 * a * (1 - t) ** 2 * t + 3 * b * (1 - t) * t ** 2 + t ** 3;
  const slope = (a: number, b: number, t: number) =>
    3 * a * (1 - t) ** 2 + 6 * (b - a) * (1 - t) * t + 3 * (1 - b) * t ** 2;

  return (progress: number) => {
    if (progress <= 0) return 0;
    if (progress >= 1) return 1;
    let t = progress;
    for (let step = 0; step < NEWTON_STEPS; step++) {
      const currentSlope = slope(x1, x2, t);
      if (currentSlope === 0) break;
      t -= (curve(x1, x2, t) - progress) / currentSlope;
    }
    return curve(y1, y2, t);
  };
}

export function clamp01(value: number) {
  return Math.min(1, Math.max(0, value));
}
