<script setup lang="ts">
import type { ValidationContact } from '~/types/verification';

// One person in "Bevestiging aanvragen" (iOS personRow): their photo or initials, the name, then function, department
// and location, so two people with the same name differ, and a round tick like a radio button.
const props = defineProps<{
  person: ValidationContact;
  details: string;
  isChosen: boolean;
  photoUrl?: string | null;
}>();

const emit = defineEmits<{
  choose: [];
}>();

// A photo link that no longer works (they last an hour) falls back to the initials.
const photoFailed = ref(false);
watch(
  () => props.photoUrl,
  () => (photoFailed.value = false),
);
</script>

<template>
  <button
    type="button"
    role="radio"
    :aria-checked="isChosen"
    :class="isChosen ? 'border-brand bg-tint' : 'border-card-border bg-white hover:bg-surface'"
    class="flex w-full items-center gap-3 rounded-xl border px-3.5 py-3 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
    @click="emit('choose')"
  >
    <span class="flex size-9 shrink-0 items-center justify-center overflow-hidden rounded-full border border-card-border bg-tint text-xs font-semibold text-brand" aria-hidden="true">
      <img v-if="photoUrl && !photoFailed" :src="photoUrl" alt="" class="size-full object-cover" @error="photoFailed = true" />
      <template v-else>{{ initialsOf(person.name) }}</template>
    </span>
    <span class="flex min-w-0 flex-1 flex-col gap-0.75">
      <span translate="no" class="text-sm font-semibold text-heading">{{ person.name }}</span>
      <span class="text-xs text-subtle">{{ details }}</span>
    </span>
    <span
      :class="isChosen ? 'border-[6px] border-brand' : 'border-[1.5px] border-field-line'"
      class="size-5.5 shrink-0 rounded-full bg-white"
      aria-hidden="true"
    />
  </button>
</template>
