<script setup lang="ts">
// The round logo on a vault card (Figma "image 4"): the organisation's logo when the item is linked to one, otherwise
// the first letter (VaultMonogram). A logo that does not load also falls back to the letter.
const props = defineProps<{
  name: string;
  logoUrl: string | null;
  size: number;
}>();

const hasFailed = ref(false);
watch(
  () => props.logoUrl,
  () => (hasFailed.value = false),
);
</script>

<template>
  <span
    v-if="logoUrl && !hasFailed"
    class="flex shrink-0 items-center justify-center overflow-hidden rounded-full border border-card-border bg-white"
    :style="{ width: `${size}px`, height: `${size}px` }"
    aria-hidden="true"
  >
    <img :src="logoUrl" alt="" class="size-full object-cover" loading="lazy" referrerpolicy="no-referrer" @error="hasFailed = true" />
  </span>
  <VaultMonogram v-else :name="name" :size="size" />
</template>
