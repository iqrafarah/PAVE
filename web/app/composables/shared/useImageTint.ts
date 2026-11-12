// The soft colour behind a vault card, taken from its logo or cover (Figma: the orange Frencken logo on apricot, the
// green Plus logo on green): the band of a grid card and the fade of a list card. The strongest colour of the picture
// is mixed with white, so text stays readable.
// Null while the picture loads, when it cannot be read (another site that does not allow it) or when it has no colour:
// the card then keeps the colour of its category.

const SAMPLE_SIZE = 32;
// How much of the picture's colour is in the tint; the rest is white. Low on purpose: an accent, not a strong colour.
const STRENGTH = 0.16;
const tints = new Map<string, Promise<string | null>>();

function readTint(url: string) {
  return new Promise<string | null>((resolve) => {
    const image = new Image();
    image.crossOrigin = 'anonymous';
    image.decoding = 'async';
    image.onerror = () => resolve(null);
    image.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        canvas.width = SAMPLE_SIZE;
        canvas.height = SAMPLE_SIZE;
        const context = canvas.getContext('2d', { willReadFrequently: true });
        if (!context) return resolve(null);
        context.drawImage(image, 0, 0, SAMPLE_SIZE, SAMPLE_SIZE);
        resolve(vividColour(context.getImageData(0, 0, SAMPLE_SIZE, SAMPLE_SIZE).data));
      } catch {
        // The picture comes from a site that does not allow reading it.
        resolve(null);
      }
    };
    image.src = url;
  });
}

/**
 * The colour that stands out most, the same way as iOS (VaultLogoLook.strongestColor): white, black and grey count for
 * nothing, and the more saturated and bright a pixel is, the more it weighs. The pixels are grouped by hue and the
 * heaviest group gives its average colour.
 */
function vividColour(pixels: Uint8ClampedArray) {
  const BINS = 24;
  const weights = new Array<number>(BINS).fill(0);
  const sums = Array.from({ length: BINS }, () => ({ r: 0, g: 0, b: 0, w: 0 }));
  for (let index = 0; index < pixels.length; index += 4) {
    if (pixels[index + 3]! < 128) continue;
    const [r, g, b] = [pixels[index]! / 255, pixels[index + 1]! / 255, pixels[index + 2]! / 255];
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const saturation = max === 0 ? 0 : (max - min) / max;
    if (saturation <= 0.25 || max <= 0.2) continue;
    let hue = max === r ? (g - b) / (max - min) : max === g ? 2 + (b - r) / (max - min) : 4 + (r - g) / (max - min);
    hue = (((hue / 6) % 1) + 1) % 1;
    const bin = Math.min(Math.floor(hue * BINS), BINS - 1);
    const weight = saturation * max;
    weights[bin]! += weight;
    const sum = sums[bin]!;
    sum.r += r * weight;
    sum.g += g * weight;
    sum.b += b * weight;
    sum.w += weight;
  }
  const best = weights.indexOf(Math.max(...weights));
  const total = sums[best]!;
  if (total.w <= 0) return null;
  const mix = (channel: number) => Math.round(255 - STRENGTH * (255 - (channel / total.w) * 255));
  return `rgb(${mix(total.r)} ${mix(total.g)} ${mix(total.b)})`;
}

export function useImageTint(url: MaybeRefOrGetter<string | null | undefined>) {
  const tint = ref<string | null>(null);
  watch(
    () => toValue(url),
    async (current) => {
      tint.value = null;
      if (!current || import.meta.server) return;
      // A cover link changes every time the vault is read; its path without the signature stays the same.
      const key = current.split('?')[0]!;
      if (!tints.has(key)) tints.set(key, readTint(current));
      const result = await tints.get(key)!;
      if (toValue(url) === current) tint.value = result;
    },
    { immediate: true },
  );
  return tint;
}
