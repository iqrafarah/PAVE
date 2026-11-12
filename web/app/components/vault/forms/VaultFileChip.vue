<script setup lang="ts">
// The chosen file above the form (Figma "LiveWall-eindstage-verslag.pdf"): its name, type and size, and ✕ to take it away.
const props = defineProps<{
  file: File;
}>();

const emit = defineEmits<{
  remove: [];
}>();

const details = computed(() => describeFile(props.file));
</script>

<template>
  <div class="flex min-h-17.75 items-center gap-3.5 rounded-xl bg-tint py-2.75 pl-2.5 pr-3">
    <span class="flex size-12 shrink-0 items-center justify-center rounded-field bg-badge">
      <VaultIcon src="/images/vault/file.svg" :width="28" :height="28" class="text-brand" />
    </span>
    <span class="flex min-w-0 flex-1 flex-col gap-0.5">
      <span class="truncate font-heading text-sm font-semibold text-heading">{{ file.name }}</span>
      <span class="text-xs font-medium text-heading">{{ details }}</span>
    </span>
    <button
      type="button"
      :aria-label="`${VAULT_REMOVE_FILE}: ${file.name}`"
      :title="VAULT_REMOVE_FILE"
      class="flex size-9 shrink-0 items-center justify-center rounded-full hover:bg-white focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('remove')"
    >
      <VaultIcon src="/images/vault/file-remove.svg" :width="10.8778" :height="10.8778" class="text-heading" />
    </button>
  </div>
</template>
