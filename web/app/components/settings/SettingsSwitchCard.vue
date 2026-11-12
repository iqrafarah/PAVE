<script setup lang="ts">
// A setting you turn on or off (iOS SettingsScreen): the title with a switch, and a line that explains it.
defineProps<{
  title: string;
  explanation: string;
}>();

const isOn = defineModel<boolean>({ required: true });
const explanationId = useId();
</script>

<template>
  <div class="flex flex-col gap-2 rounded-pill bg-white p-3">
    <label class="flex cursor-pointer items-center gap-4">
      <span class="flex-1 text-base font-semibold text-heading">{{ title }}</span>
      <input v-model="isOn" type="checkbox" role="switch" :aria-describedby="explanationId" class="peer sr-only" />
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
    <p :id="explanationId" class="text-xs/normal text-subtle">{{ explanation }}</p>
  </div>
</template>
