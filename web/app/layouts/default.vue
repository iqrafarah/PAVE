<script setup lang="ts">
const route = useRoute();
const voice = useAylaVoice();
const { restore: restorePanel } = useAylaPanel();

// The chat history opens the way the user left it.
onMounted(restorePanel);

// A spoken conversation belongs to Ayla's screens: going elsewhere ends it.
watch(
  () => route.meta.showsChats,
  (showsChats) => {
    if (!showsChats) voice.stop();
  },
);

// The chat history stays mounted while moving between the home screen and a chat.
const showsChats = computed(() => route.meta.showsChats === true);
</script>

<template>
  <div class="flex h-dvh overflow-hidden bg-surface text-ink">
    <LayoutIconRail class="max-md:hidden" />
    <LayoutMenuDrawer />
    <AylaChatSidebar v-if="showsChats" />
    <div class="flex min-w-0 flex-1 flex-col bg-white">
      <slot />
    </div>
    <VaultAddDialog />
  </div>
</template>
