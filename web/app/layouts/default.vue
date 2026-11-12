<script setup lang="ts">
const route = useRoute();
const voice = useAylaVoice();
const personal = usePersonalisation();
const user = useSupabaseUser();

onMounted(() => {
  // The look kept in the account is extra: when it cannot be read, the look of this browser simply stays.
  watch(() => user.value?.sub, () => void Promise.resolve().then(() => personal.loadAccount()).catch(() => {}), { immediate: true });
});
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
      <!-- A page that breaks while it is drawn is replaced by a message; the menu around it keeps working. -->
      <NuxtErrorBoundary>
        <slot />
        <template #error="{ error, clearError }">
          <LayoutPageError :error="error" @retry="clearError" />
        </template>
      </NuxtErrorBoundary>
    </div>
    <VaultAddDialog />
  </div>
</template>
