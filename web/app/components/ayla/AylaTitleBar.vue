<script setup lang="ts">
// "/ Ayla" at the top of the chat (Figma: 30px, brand green). The slash is only a logo: the PAVE logo opens the
// sidebars (in the rail on wide screens, at the top left on small screens).
withDefaults(
  defineProps<{
    showsTitle?: boolean;
  }>(),
  { showsTitle: true },
);
</script>

<template>
  <header class="flex shrink-0 items-center gap-2 px-4 pt-7.5 sm:px-13.25">
    <LayoutMenuLogo />
    <AylaSlashIcon v-if="showsTitle" class="h-7.5 w-4.5" />
    <h1 v-if="showsTitle" class="text-3xl font-semibold text-brand">{{ AYLA_NAME }}</h1>
    <h1 v-else class="sr-only">{{ AYLA_NAME }}</h1>
  </header>
</template>
