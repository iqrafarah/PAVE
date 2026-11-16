<script setup lang="ts">
// "Verplaatsen en schalen" (iOS VaultImageFramer): a chosen logo or cover is moved and zoomed inside its frame, a
// circle for the logo and a wide band for the cover, and only what is inside the frame is kept. On the web you drag
// with the mouse or a finger, and zoom with the slider, the scroll wheel or the + and - keys.
const props = defineProps<{
  // The picture as chosen; null closes the window.
  image: File | Blob | null;
  shape: 'circle' | 'band';
}>();

const emit = defineEmits<{
  use: [file: File];
  close: [];
  // The browser cannot show this picture (HEIC, for instance), so it cannot be framed.
  unreadable: [];
}>();

const MAXIMUM_ZOOM = 5;
// What is kept, as on iOS: 600 x 600 for the logo, 1600 x 400 for the cover.
const OUTPUT = { circle: { width: 600, height: 600 }, band: { width: 1600, height: 400 } };

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const frameRef = useTemplateRef<HTMLDivElement>('frame');
const titleId = useId();
const zoomId = useId();

const source = ref<HTMLImageElement | null>(null);
const sourceUrl = ref<string | null>(null);
const frame = ref({ width: 0, height: 0 });
const zoom = ref(1);
const offset = ref({ x: 0, y: 0 });
const drag = ref<{ x: number; y: number; startX: number; startY: number } | null>(null);

/** The picture on screen: it always covers the frame, and zoom makes it larger. */
const shown = computed(() => {
  if (!source.value || !frame.value.width) return { width: 0, height: 0 };
  const scale = Math.max(frame.value.width / source.value.naturalWidth, frame.value.height / source.value.naturalHeight) * zoom.value;
  return { width: source.value.naturalWidth * scale, height: source.value.naturalHeight * scale };
});

const imageStyle = computed(() => ({
  width: `${shown.value.width}px`,
  height: `${shown.value.height}px`,
  left: `${(frame.value.width - shown.value.width) / 2 + offset.value.x}px`,
  top: `${(frame.value.height - shown.value.height) / 2 + offset.value.y}px`,
}));

/** The picture never leaves a gap inside the frame. */
function clamp(next: { x: number; y: number }) {
  const limitX = Math.max(0, (shown.value.width - frame.value.width) / 2);
  const limitY = Math.max(0, (shown.value.height - frame.value.height) / 2);
  return { x: Math.min(Math.max(next.x, -limitX), limitX), y: Math.min(Math.max(next.y, -limitY), limitY) };
}

function setZoom(value: number) {
  zoom.value = Math.min(Math.max(value, 1), MAXIMUM_ZOOM);
  offset.value = clamp(offset.value);
}

function measure() {
  const box = frameRef.value?.getBoundingClientRect();
  if (!box) return;
  frame.value = { width: box.width, height: box.height };
  offset.value = clamp(offset.value);
}

function release() {
  if (sourceUrl.value) URL.revokeObjectURL(sourceUrl.value);
  sourceUrl.value = null;
  source.value = null;
}

watch(
  () => props.image,
  (image) => {
    release();
    if (!image) {
      if (dialogRef.value?.open) dialogRef.value.close();
      return;
    }
    const url = URL.createObjectURL(image);
    const picture = new Image();
    picture.onload = async () => {
      if (props.image !== image) return URL.revokeObjectURL(url);
      sourceUrl.value = url;
      source.value = picture;
      zoom.value = 1;
      offset.value = { x: 0, y: 0 };
      if (!dialogRef.value?.open) dialogRef.value?.showModal();
      await nextTick();
      measure();
    };
    picture.onerror = () => {
      URL.revokeObjectURL(url);
      if (props.image === image) emit('unreadable');
    };
    picture.src = url;
  },
);

function startDrag(event: PointerEvent) {
  if (event.button !== 0) return;
  (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
  drag.value = { x: event.clientX, y: event.clientY, startX: offset.value.x, startY: offset.value.y };
}

function moveDrag(event: PointerEvent) {
  if (!drag.value) return;
  offset.value = clamp({ x: drag.value.startX + event.clientX - drag.value.x, y: drag.value.startY + event.clientY - drag.value.y });
}

function handleWheel(event: WheelEvent) {
  setZoom(zoom.value - event.deltaY * 0.002);
}

function handleKeydown(event: KeyboardEvent) {
  const step = event.shiftKey ? 40 : 10;
  if (event.key === '+' || event.key === '=') setZoom(zoom.value + 0.25);
  else if (event.key === '-') setZoom(zoom.value - 0.25);
  else if (event.key === 'ArrowLeft') offset.value = clamp({ ...offset.value, x: offset.value.x + step });
  else if (event.key === 'ArrowRight') offset.value = clamp({ ...offset.value, x: offset.value.x - step });
  else if (event.key === 'ArrowUp') offset.value = clamp({ ...offset.value, y: offset.value.y + step });
  else if (event.key === 'ArrowDown') offset.value = clamp({ ...offset.value, y: offset.value.y - step });
  else return;
  event.preventDefault();
}

/** Draws what is inside the frame on a white sheet and hands it over as a JPEG. */
function use() {
  if (!source.value || !shown.value.width) return;
  const output = OUTPUT[props.shape];
  const scale = shown.value.width / source.value.naturalWidth;
  const crop = {
    x: ((shown.value.width - frame.value.width) / 2 - offset.value.x) / scale,
    y: ((shown.value.height - frame.value.height) / 2 - offset.value.y) / scale,
    width: frame.value.width / scale,
    height: frame.value.height / scale,
  };
  const canvas = document.createElement('canvas');
  canvas.width = output.width;
  canvas.height = output.height;
  const context = canvas.getContext('2d');
  if (!context) return;
  context.fillStyle = '#fff';
  context.fillRect(0, 0, output.width, output.height);
  context.drawImage(source.value, crop.x, crop.y, crop.width, crop.height, 0, 0, output.width, output.height);
  canvas.toBlob(
    (blob) => {
      if (!blob) return;
      emit('use', new File([blob], props.shape === 'circle' ? 'Logo.jpeg' : 'Omslag.jpeg', { type: 'image/jpeg' }));
    },
    'image/jpeg',
    0.88,
  );
}

function handleCancel(event: Event) {
  event.preventDefault();
  emit('close');
}

onMounted(() => window.addEventListener('resize', measure));
onBeforeUnmount(() => {
  window.removeEventListener('resize', measure);
  release();
});
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    class="m-auto w-[calc(100%-2rem)] max-w-140 overflow-hidden rounded-modal bg-white p-0 text-heading shadow-modal backdrop:bg-backdrop"
    @cancel="handleCancel"
  >
    <div v-if="source" class="flex flex-col gap-5 p-7 max-sm:p-5">
      <div class="flex flex-col gap-1">
        <h2 :id="titleId" class="font-heading text-xl font-semibold text-heading">{{ VAULT_REFRAME }}</h2>
        <p class="text-xs font-medium text-subtle">{{ VAULT_REFRAME_HINT }}</p>
      </div>

      <div class="flex items-center justify-center rounded-2xl bg-tint p-5">
        <div
          ref="frame"
          tabindex="0"
          role="img"
          :aria-label="VAULT_REFRAME_HINT"
          :class="[shape === 'circle' ? 'aspect-square w-64 max-w-full rounded-full' : 'aspect-[4/1] w-full rounded-xl', drag ? 'cursor-grabbing' : 'cursor-grab']"
          class="relative touch-none select-none overflow-hidden bg-white shadow-[0_0_0_2px_white,0_0_0_3px_var(--color-drop-line)] focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand"
          @pointerdown="startDrag"
          @pointermove="moveDrag"
          @pointerup="drag = null"
          @pointercancel="drag = null"
          @wheel.prevent="handleWheel"
          @keydown="handleKeydown"
        >
          <img :src="sourceUrl ?? undefined" alt="" draggable="false" class="pointer-events-none absolute max-w-none" :style="imageStyle" />
        </div>
      </div>

      <div class="flex items-center gap-3">
        <label :for="zoomId" class="text-sm font-medium text-heading">{{ VAULT_REFRAME_ZOOM }}</label>
        <input
          :id="zoomId"
          type="range"
          min="1"
          :max="MAXIMUM_ZOOM"
          step="0.05"
          :value="zoom"
          class="min-w-0 flex-1 cursor-pointer accent-brand"
          @input="setZoom(Number(($event.target as HTMLInputElement).value))"
        />
      </div>

      <div class="flex justify-end gap-2.5">
        <button
          type="button"
          class="min-h-10 min-w-25.75 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="emit('close')"
        >
          {{ VAULT_CANCEL }}
        </button>
        <button
          type="button"
          class="min-h-10 min-w-25.75 rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="use"
        >
          {{ VAULT_REFRAME_USE }}
        </button>
      </div>
    </div>
  </dialog>
</template>
