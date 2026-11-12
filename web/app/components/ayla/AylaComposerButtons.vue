<script setup lang="ts">
// Microphone and the round send button (Figma: 30px, brand green, white arrow). While Ayla writes it stops her.
// With nothing typed it is "Praat met Ayla" instead, as on the iPhone: it starts a spoken conversation.
defineProps<{
  canSend: boolean;
  isWriting: boolean;
  isDictationSupported: boolean;
  isListening: boolean;
  canTalk?: boolean;
  // While talking with Ayla: the microphone mutes and the green button stops the conversation.
  isTalking?: boolean;
  isMuted?: boolean;
}>();

const emit = defineEmits<{
  send: [];
  stop: [];
  toggleDictation: [];
  talk: [];
  mute: [];
  stopTalking: [];
}>();
</script>

<template>
  <div class="flex shrink-0 items-center gap-2">
    <button
      v-if="isTalking"
      type="button"
      :aria-pressed="isMuted"
      :aria-label="isMuted ? VOICE_UNMUTE : VOICE_MUTE"
      :title="isMuted ? VOICE_UNMUTE : VOICE_MUTE"
      :class="isMuted ? 'bg-tint' : 'hover:bg-surface'"
      class="relative flex size-8 items-center justify-center rounded-full focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('mute')"
    >
      <VaultIcon src="/images/ayla/microphone.svg" :width="15" :height="21" class="text-brand" :class="isMuted ? 'opacity-50' : ''" />
      <span v-if="isMuted" class="absolute h-5.5 w-0.5 -rotate-45 rounded-full bg-critical" aria-hidden="true" />
    </button>
    <button
      v-else-if="isDictationSupported"
      type="button"
      :aria-pressed="isListening"
      :class="isListening ? 'bg-tint' : 'hover:bg-surface'"
      class="flex size-8 items-center justify-center rounded-full focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('toggleDictation')"
    >
      <VaultIcon src="/images/ayla/microphone.svg" :width="15" :height="21" class="text-brand" />
      <span class="sr-only">{{
        isListening ? AYLA_STOP_DICTATE_LABEL : AYLA_DICTATE_LABEL
      }}</span>
    </button>

    <button
      v-if="isTalking && !canSend"
      type="button"
      :aria-label="VOICE_STOP"
      :title="VOICE_STOP"
      class="flex size-7.5 items-center justify-center rounded-full bg-brand text-white shadow-composer hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('stopTalking')"
    >
      <LayoutPaveIcon name="xMark" class="size-4" />
    </button>
    <button
      v-else-if="isWriting && !isTalking"
      type="button"
      class="flex size-7.5 items-center justify-center rounded-full bg-brand text-tint shadow-composer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('stop')"
    >
      <span class="size-2.5 rounded-xs bg-tint" aria-hidden="true" />
      <span class="sr-only">{{ AYLA_STOP_LABEL }}</span>
    </button>
    <button
      v-else-if="canTalk && !canSend"
      type="button"
      :aria-label="VOICE_TALK"
      :title="VOICE_TALK"
      class="flex size-7.5 items-center justify-center rounded-full bg-brand shadow-composer hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('talk')"
    >
      <AylaPixelWaveIcon class="size-4" />
    </button>
    <button
      v-else
      type="button"
      :disabled="!canSend"
      class="flex size-7.5 items-center justify-center rounded-full bg-brand focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('send')"
    >
      <VaultIcon src="/images/ayla/send.svg" :width="12.9" :height="15.9" class="text-white" />
      <span class="sr-only">{{ AYLA_SEND_LABEL }}</span>
    </button>
  </div>
</template>
