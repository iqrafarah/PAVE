<script setup lang="ts">
// The sentence Ayla is saying, under her orb (iOS voice captions). Only with "Tekst bij praten met Ayla" on; screen
// readers get the same through the dock's own live text, so this one is hidden from them. The space stays reserved
// while talking, so the orb does not move when a caption comes or goes.
const CAPTION_TICK_MS = 250;

const voice = useAylaVoice();
const voiceText = useAylaVoiceText();
const now = ref(Date.now());
let clockTimer: ReturnType<typeof setInterval> | undefined;

const isSpeaking = computed(() => voice.session.value.state === 'speaking');
const sentence = computed(() => voice.getSpokenSentence(now.value) ?? '');

function stopClock() {
  clearInterval(clockTimer);
  clockTimer = undefined;
}

function startClock() {
  stopClock();
  now.value = Date.now();
  clockTimer = setInterval(() => (now.value = Date.now()), CAPTION_TICK_MS);
}

watch(isSpeaking, (speaking) => (speaking ? startClock() : stopClock()));

onMounted(() => {
  voiceText.load();
  if (isSpeaking.value) startClock();
});
onBeforeUnmount(stopClock);
</script>

<template>
  <div
    v-if="voiceText.showsVoiceText.value"
    class="mt-3 flex h-15 w-full max-w-110 justify-center px-4"
    aria-hidden="true"
  >
    <Transition
      mode="out-in"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
      enter-active-class="transition-opacity duration-300 ease-out motion-reduce:transition-none"
      leave-active-class="transition-opacity duration-150 ease-in motion-reduce:transition-none"
    >
      <p v-if="sentence" :key="sentence" class="line-clamp-3 text-center text-sm/5 font-medium text-heading">
        {{ sentence }}
      </p>
    </Transition>
  </div>
</template>
