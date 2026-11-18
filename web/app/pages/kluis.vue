<script setup lang="ts">
// The vault inside Ayla's screen (Figma 1209:55066 and 1209:53998): the chats on the left, the vault in the middle
// and the chatbox with "Kluis" at the bottom. A question asked here, or a chat picked in the list, stays on this page
// (?chat=<id> in the address), so you keep talking with Ayla while the vault is open. What the vault does follows iOS
// (VaultScreen).
definePageMeta({ showsChats: true });
useHead({ title: `${VAULT_TITLE} - PAVE` });

const route = useRoute();
const conversation = useAylaConversation();
const lock = useAylaChatLock();
const chatId = computed(() => (typeof route.query.chat === 'string' ? route.query.chat : null));

async function showChat(id: string | null) {
  if (id) {
    // A locked chat only opens on its own page, which asks for the PIN first.
    if (lock.state.value.status === 'idle') await lock.load();
    if (lock.isLocked(id)) return navigateTo(`/ayla/${id}`, { replace: true });
    if (conversation.state.value.conversationId !== id) conversation.open(id);
  } else if (conversation.state.value.conversationId || conversation.state.value.messages.length) {
    conversation.startNew();
  }
}

watch(chatId, showChat);

onMounted(() => {
  if (chatId.value) showChat(chatId.value);
  else conversation.startNew();
});
</script>

<template>
  <div class="relative flex min-h-0 flex-1 flex-col">
    <!-- The title sits in the middle, as on every page; the vault scrolls on underneath it. -->
    <!-- The vault always shows, also while you chat: the title has no background and the vault scrolls on underneath it. -->
    <AylaTitleBar class="pointer-events-none absolute inset-x-0 top-0 z-10 [&_a,&_button]:pointer-events-auto" />
    <AylaChatView screen="vault">
      <template #empty>
        <VaultLibrary />
      </template>
    </AylaChatView>
  </div>
</template>
