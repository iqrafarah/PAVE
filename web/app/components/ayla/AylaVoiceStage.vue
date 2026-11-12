<script setup lang="ts">
// Talking with Ayla (iOS AylaVoiceStage): the orb large in the middle with one caption underneath (what you say,
// what Ayla answers, or what she is doing), the field of blocks around it and the voice bar at the bottom. The
// conversation keeps growing in the chat history. Click the orb to interrupt Ayla, or to send what you said at once.
const voice = useAylaVoice();
const { showsVoiceText, load: loadVoiceText } = useAylaVoiceText();
const now = ref(Date.now());
const orbRef = useTemplateRef<HTMLButtonElement>('orb');
const captionRef = useTemplateRef<HTMLParagraphElement>('caption');
let timer: ReturnType<typeof setInterval> | undefined;

const state = computed(() => voice.session.value.state);
const caption = computed(() => voice.getCaption(now.value));
const orbLabel = computed(() => (state.value === 'speaking' || state.value === 'thinking' ? AYLA_STOP_LABEL : VOICE_TALK));
const getLevel = () => (state.value === 'speaking' ? voice.getSpeakerLevel() : voice.getMicrophoneLevel());
const getIcon = () => voice.getIcon(Date.now());

// Dragging the orb down puts it above the text field, as on the iPhone.
const DRAG_DISTANCE = 40;
let dragStartY: number | null = null;
let wasDragged = false;

function startDrag(event: PointerEvent) {
  dragStartY = event.clientY;
  wasDragged = false;
}

function endDrag(event: PointerEvent) {
  if (dragStartY !== null && event.clientY - dragStartY > DRAG_DISTANCE) {
    wasDragged = true;
    voice.isCompact.value = true;
  }
  dragStartY = null;
}

function handleOrbClick() {
  if (!wasDragged) voice.tapOrb();
}

onMounted(() => {
  loadVoiceText();
  timer = setInterval(() => (now.value = Date.now()), 200);
});
onBeforeUnmount(() => clearInterval(timer));
</script>

<template>
  <div class="relative flex min-h-0 flex-1 flex-col items-center overflow-hidden px-4 pb-8.25">
    <!-- On the iPhone you drag the orb down to see the conversation; here it is a button. -->
    <button
      type="button"
      class="absolute right-4 top-3 z-10 flex min-h-9 items-center gap-1.5 rounded-full bg-white px-3.5 text-xs font-semibold text-heading shadow-composer hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand sm:right-13.25"
      @click="voice.isCompact.value = true"
    >
      <LayoutPaveIcon name="chat" class="size-4" />
      {{ VOICE_SHOW_CHAT }}
    </button>
    <AylaAmbientField
      :state="state"
      :get-level="getLevel"
      :get-bands="voice.getVoiceBands"
      :get-orb="() => orbRef?.getBoundingClientRect() ?? null"
      :get-quiet="() => (showsVoiceText ? (captionRef?.getBoundingClientRect() ?? null) : null)"
    />
    <div class="relative flex min-h-0 w-full flex-1 flex-col items-center justify-center gap-11">
      <button
        ref="orb"
        type="button"
        :aria-label="orbLabel"
        class="w-full max-w-60 touch-none rounded-full focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand"
        @pointerdown="startDrag"
        @pointerup="endDrag"
        @click="handleOrbClick"
      >
        <AylaPixelOrb :state="state" :get-level="getLevel" :get-icon="getIcon" />
      </button>
      <!-- Off in the settings: no line at all, but its place stays, so the orb does not move. -->
      <p
        ref="caption"
        aria-live="polite"
        :class="[
          caption.kind === 'status' ? 'text-sm font-medium text-subtle' : 'text-base font-semibold text-heading',
          { invisible: !showsVoiceText },
        ]"
        class="line-clamp-6 min-h-24 w-full max-w-78.25 text-center"
      >
        {{ caption.text }}
      </p>
    </div>
    <AylaVoiceBar
      class="relative"
      :is-muted="voice.session.value.isMuted"
      @send="voice.sendTyped"
      @mute="voice.toggleMute"
      @stop="voice.stop"
    />
  </div>
</template>
