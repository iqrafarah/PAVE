<script setup lang="ts">
// A switch row inside a card (iOS Toggle in SettingsRetentionScreen): the title with the switch beside it.
defineProps<{ title: string }>();

const isOn = defineModel<boolean>({ required: true });

// The page may ask first before the change takes; until then the switch shows the saved value.
async function toggle(event: Event) {
  const input = event.target as HTMLInputElement;
  isOn.value = input.checked;
  await nextTick();
  input.checked = isOn.value;
}
</script>

<template>
  <label class="flex min-h-11 cursor-pointer items-center gap-4">
    <span class="flex-1 text-base font-semibold text-heading">{{ title }}</span>
    <input :checked="isOn" type="checkbox" role="switch" class="peer sr-only" @change="toggle" />
    <span
      class="relative h-7.75 w-12.75 shrink-0 rounded-full bg-line transition-colors peer-checked:bg-brand peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-brand motion-reduce:transition-none"
      aria-hidden="true"
    >
      <span
        :class="isOn ? 'translate-x-5' : 'translate-x-0'"
        class="absolute left-0.5 top-0.5 size-6.75 rounded-full bg-white shadow transition-transform motion-reduce:transition-none"
      />
    </span>
  </label>
</template>
