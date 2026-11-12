<script setup lang="ts">
import type { VaultCoverChoice } from '~/types/vault';

// Step 2 "Documenten", the cover (Figma 1167:12237): a card with or without a picture on top. With a cover you add
// the picture below.
defineProps<{
  problem?: string;
}>();

const choice = defineModel<VaultCoverChoice>('choice', { required: true });
const cover = defineModel<File | null>('cover', { required: true });

const fileProblem = ref<string | null>(null);
const groupId = useId();
const problemId = useId();

const OPTIONS: { value: VaultCoverChoice; label: string; image: string }[] = [
  { value: 'none', label: VAULT_NO_COVER, image: '/images/vault/no-cover-example.png' },
  { value: 'cover', label: VAULT_COVER, image: '/images/vault/cover-example.png' },
];

function pick(file: File) {
  fileProblem.value = null;
  cover.value = file;
}
</script>

<template>
  <div class="flex flex-col">
    <p :id="groupId" class="mb-2.5 text-base font-semibold text-heading">
      {{ VAULT_COVER }}
      <span class="text-brand" aria-hidden="true">*</span>
      <span class="sr-only">({{ VAULT_REQUIRED }})</span>
    </p>
    <div role="radiogroup" :aria-labelledby="groupId" class="grid grid-cols-2 gap-4.75">
      <label
        v-for="option in OPTIONS"
        :key="option.value"
        :class="choice === option.value ? 'border-cover-selected-line bg-cover-selected' : 'border-field-line bg-white hover:bg-surface'"
        class="relative flex min-h-34.75 cursor-pointer flex-col items-center rounded-field border-2 pt-3 has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand"
      >
        <input v-model="choice" type="radio" :value="option.value" name="vault-cover" class="sr-only" />
        <img :src="option.image" alt="" width="100" height="80" class="h-20 w-25 rounded-t-[0.625rem] object-cover" />
        <span class="mt-3.5 text-xs font-semibold text-heading">{{ option.label }}</span>
      </label>
    </div>

    <template v-if="choice === 'cover'">
      <VaultFileChip v-if="cover" class="mt-5" :file="cover" @remove="cover = null" />
      <VaultDropZone
        v-else
        class="mt-5"
        kind="cover"
        is-compact
        :described-by="fileProblem || problem ? problemId : undefined"
        @pick="pick"
        @problem="fileProblem = $event"
      />
    </template>
    <p v-if="fileProblem || problem" :id="problemId" role="alert" class="mt-2 text-xs text-danger">{{ fileProblem ?? problem }}</p>
  </div>
</template>
