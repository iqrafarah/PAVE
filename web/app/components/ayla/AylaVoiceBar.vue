<script setup lang="ts">
// The bottom bar while talking (iOS AylaVoiceBar), like ChatGPT's: a text field (Ayla answers a typed question out
// loud too), a round button to mute the microphone and a round green button to stop.
defineProps<{
  isMuted: boolean;
}>();

const emit = defineEmits<{
  send: [text: string];
  mute: [];
  stop: [];
}>();

const text = ref('');
const canSend = computed(() => text.value.trim().length > 0);

function send() {
  if (!canSend.value) return;
  emit('send', text.value);
  text.value = '';
}
</script>

<template>
  <div class="flex w-full max-w-147.75 items-end gap-2.5">
    <form
      class="flex min-h-13.25 min-w-0 flex-1 items-center rounded-composer bg-white pl-5 pr-1.75 shadow-composer"
      @submit.prevent="send"
    >
      <label for="ayla-voice-text" class="sr-only">{{ AYLA_PLACEHOLDER }}</label>
      <input
        id="ayla-voice-text"
        v-model="text"
        type="text"
        :placeholder="AYLA_PLACEHOLDER"
        class="min-w-0 flex-1 bg-transparent py-4 text-sm font-medium text-heading placeholder:text-subtle/60 focus:outline-none"
      />
      <button
        v-if="canSend"
        type="submit"
        class="flex size-7.5 items-center justify-center rounded-full bg-brand focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      >
        <VaultIcon src="/images/ayla/send.svg" :width="12.9" :height="15.9" class="text-white" />
        <span class="sr-only">{{ AYLA_SEND_LABEL }}</span>
      </button>
    </form>
    <button
      type="button"
      :aria-pressed="isMuted"
      :aria-label="isMuted ? VOICE_UNMUTE : VOICE_MUTE"
      :class="isMuted ? 'text-subtle' : 'text-heading'"
      class="relative flex size-13.25 shrink-0 items-center justify-center rounded-full bg-white shadow-composer hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('mute')"
    >
      <LayoutPaveIcon name="microphone" class="h-6 w-4.5" />
      <span v-if="isMuted" class="absolute h-6.5 w-0.75 -rotate-45 rounded-full bg-critical" aria-hidden="true" />
    </button>
    <button
      type="button"
      :aria-label="VOICE_STOP"
      class="flex size-13.25 shrink-0 items-center justify-center rounded-full bg-brand text-white shadow-composer hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('stop')"
    >
      <LayoutPaveIcon name="xMark" class="size-5" />
    </button>
  </div>
</template>
