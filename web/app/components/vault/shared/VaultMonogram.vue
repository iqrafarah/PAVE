<script setup lang="ts">
// A round white badge used when there is no logo (iOS CompanyMonogram): a file icon for the evidence's file (PDF, Word,
// text or photo, public/images/vault/files) when it has one, otherwise the first letter of the organisation.
const props = defineProps<{
  name: string;
  size: number;
  // The first document of the evidence; its kind decides the icon shown instead of the letter.
  fileName?: string | null;
}>();

const FILE_ICONS: Record<string, string> = {
  pdf: 'pdf',
  doc: 'word',
  docx: 'word',
  txt: 'text',
  jpg: 'image',
  jpeg: 'image',
  png: 'image',
  heic: 'image',
};

const fileIcon = computed(() => {
  const name = props.fileName?.trim() ?? '';
  if (!name) return null;
  return `/images/vault/files/${FILE_ICONS[getExtension(name)] ?? 'text'}.svg`;
});
const letter = computed(() => props.name.trim().charAt(0).toLocaleUpperCase('nl') || '?');
</script>

<template>
  <span
    class="flex shrink-0 items-center justify-center rounded-full border border-card-border bg-white font-bold text-brand"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${(size * 26) / 64}px` }"
    aria-hidden="true"
  >
    <img v-if="fileIcon" :src="fileIcon" alt="" class="block" :style="{ width: `${size * 0.6}px`, height: `${size * 0.6}px` }" />
    <template v-else>{{ letter }}</template>
  </span>
</template>
