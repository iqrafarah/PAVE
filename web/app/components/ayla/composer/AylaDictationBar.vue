<script setup lang="ts">
// Takes the place of the text field while you dictate (iOS AylaDictationBar): your words appear as you speak, the
// pixel wave moves with your voice and the timer runs. ✕ throws the recording away; ✓ keeps the text in the field,
// so you can read and change it before you send it.
defineProps<{
  text: string;
}>();

const emit = defineEmits<{
  cancel: [];
  done: [];
}>();

const meter = useMicrophoneMeter();
const seconds = ref(0);
const doneRef = useTemplateRef<HTMLButtonElement>('done');
let timer: ReturnType<typeof setInterval> | undefined;

const time = computed(() => `${Math.floor(seconds.value / 60)}:${String(seconds.value % 60).padStart(2, '0')}`);

onMounted(() => {
  meter.start();
  timer = setInterval(() => (seconds.value += 1), 1000);
  doneRef.value?.focus();
});
onBeforeUnmount(() => clearInterval(timer));
</script>

<template>
  <div class="w-full max-w-147.75 rounded-composer bg-white shadow-composer" @keydown.esc="emit('cancel')">
    <p
      aria-live="polite"
      :class="text ? 'text-heading' : 'text-subtle'"
      class="line-clamp-3 px-4.5 pt-3.5 text-sm font-medium"
    >
      {{ text || DICTATION_LISTENING }}
    </p>
    <div class="flex items-center gap-2 pl-1 pr-1.75">
      <button
        type="button"
        :aria-label="DICTATION_CANCEL"
        :title="DICTATION_CANCEL"
        class="flex h-13.25 w-11 items-center justify-center rounded-full text-heading hover:text-critical focus-visible:outline-2 focus-visible:-outline-offset-4 focus-visible:outline-brand"
        @click="emit('cancel')"
      >
        <LayoutPaveIcon name="xMark" class="size-5" />
      </button>
      <AylaLevelWave :get-level="meter.getMicrophoneLevel" />
      <span class="text-xs font-medium tabular-nums text-subtle" aria-hidden="true">{{ time }}</span>
      <button
        ref="done"
        type="button"
        :aria-label="DICTATION_DONE"
        :title="DICTATION_DONE"
        class="flex size-7.5 items-center justify-center rounded-full bg-brand text-white shadow-composer hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('done')"
      >
        <LayoutPaveIcon name="check" class="size-4.5" />
      </button>
    </div>
  </div>
</template>
