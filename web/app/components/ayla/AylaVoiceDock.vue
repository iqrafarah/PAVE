<script setup lang="ts">
// Ayla's orb while you talk with her: small and compact, above her answer and the text field. It only shows while
// talking is on. Click it to interrupt Ayla, or to send what you said at once.
const voice = useAylaVoice();

const state = computed(() => voice.session.value.state);
const orbLabel = computed(() => (state.value === 'speaking' || state.value === 'thinking' ? AYLA_STOP_LABEL : VOICE_TALK));
const getLevel = () => (state.value === 'speaking' ? voice.getSpeakerLevel() : voice.getMicrophoneLevel());
const getIcon = () => voice.getIcon(Date.now());
</script>

<template>
  <div class="flex flex-col items-center">
    <button
      type="button"
      :aria-label="orbLabel"
      :title="orbLabel"
      class="size-20 rounded-full focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand"
      @click="voice.tapOrb"
    >
      <AylaPixelOrb :state="state" :get-level="getLevel" :get-icon="getIcon" />
    </button>
    <!-- What you say and what Ayla is doing stays available to screen readers. -->
    <p class="sr-only" aria-live="polite">{{ voice.getCaption(Date.now()).text }}</p>
  </div>
</template>
