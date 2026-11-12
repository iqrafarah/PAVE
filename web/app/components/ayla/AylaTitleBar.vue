<script setup lang="ts">
// "/ Ayla" at the top of the chat (Figma: 30px, brand green). The slash is only a logo: the PAVE logo opens the
// sidebars (in the rail on wide screens, at the top left on small screens).
// It sits in the middle, like the title of every other page (Instellingen, Plan, Profiel).
withDefaults(
  defineProps<{
    showsTitle?: boolean;
  }>(),
  { showsTitle: true },
);
</script>

<template>
  <!-- The menu on the left and the title in the middle, as on the settings pages. -->
  <header class="grid shrink-0 grid-cols-[1fr_auto_1fr] items-center gap-2 px-4 pt-7.5 sm:px-13.25">
    <div class="justify-self-start"><LayoutMenuLogo /></div>
    <div v-if="showsTitle" class="flex items-center justify-center gap-2">
      <AylaSlashIcon class="h-7.5 w-4.5" />
      <h1 class="text-3xl font-semibold text-brand max-sm:text-2xl">{{ AYLA_NAME }}</h1>
    </div>
    <h1 v-else class="sr-only">{{ AYLA_NAME }}</h1>
    <span aria-hidden="true" />
  </header>
</template>
