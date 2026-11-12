// The soft colour behind a vault card, taken from its logo or cover (Figma: the orange Frencken logo on apricot, the
// green Plus logo on green). The most vivid colour of the picture is mixed with white, so text stays readable.
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

/** Groups the pixels into rough colours and takes the one that is both common and vivid. */
function vividColour(pixels: Uint8ClampedArray) {
  const groups = new Map<number, { r: number; g: number; b: number; count: number; saturation: number }>();
  for (let index = 0; index < pixels.length; index += 4) {
    const [r, g, b, alpha] = [pixels[index]!, pixels[index + 1]!, pixels[index + 2]!, pixels[index + 3]!];
    if (alpha < 200) continue;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const saturation = max === 0 ? 0 : (max - min) / max;
    // White, black and grey say nothing about the brand.
    if (saturation < 0.25 || max < 50) continue;
    const key = ((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5);
    const group = groups.get(key) ?? { r: 0, g: 0, b: 0, count: 0, saturation: 0 };
    group.r += r;
    group.g += g;
    group.b += b;
    group.count += 1;
    group.saturation += saturation;
    groups.set(key, group);
  }
  let best: { r: number; g: number; b: number; count: number; saturation: number } | null = null;
  for (const group of groups.values()) {
    if (!best || group.count * (group.saturation / group.count) > best.count * (best.saturation / best.count)) best = group;
  }
  // A few coloured pixels in a grey picture are noise.
  if (!best || best.count < (SAMPLE_SIZE * SAMPLE_SIZE) / 50) return null;
  const mix = (sum: number) => Math.round(255 - STRENGTH * (255 - sum / best!.count));
  return `rgb(${mix(best.r)} ${mix(best.g)} ${mix(best.b)})`;
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
