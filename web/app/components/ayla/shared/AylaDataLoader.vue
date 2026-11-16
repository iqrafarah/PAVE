<script setup lang="ts">
// The big "Gegevens ophalen" loader (Figma "Kluis doorzoeken"): placeholder cards with Ayla's blocks on top.
// Only for waits that really take long: reading an attachment, or a first data load. It appears after
// DATA_LOADER_DELAY_MS, so short waits (such as opening a chat that loads quickly) show nothing at all.
withDefaults(
  defineProps<{
    // The placeholder cards fit the chat (vacancies); other screens show only the blocks.
    showsCards?: boolean;
  }>(),
  { showsCards: true },
);

const isShown = ref(false);
let timer: ReturnType<typeof setTimeout> | undefined;

onMounted(() => {
  timer = setTimeout(() => (isShown.value = true), DATA_LOADER_DELAY_MS);
});
onBeforeUnmount(() => clearTimeout(timer));
</script>

<template>
  <div class="relative min-h-0 flex-1 overflow-hidden px-4 pt-4 sm:px-13.25">
    <template v-if="isShown">
      <AylaSkeletonGrid v-if="showsCards" />
      <div class="absolute inset-0 flex items-center justify-center">
        <AylaPixelLoader mode="thinking" :glows="showsCards" :label="AYLA_FETCHING_DATA" />
      </div>
    </template>
    <span v-else role="status" class="sr-only">{{ AYLA_FETCHING_DATA }}</span>
  </div>
</template>
