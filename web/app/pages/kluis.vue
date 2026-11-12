<script setup lang="ts">
// The vault inside Ayla's screen (Figma 1209:55066 and 1209:53998): the chats on the left, the vault in the middle
// and the chatbox with "Kluis" at the bottom. A question asked here opens the chat, and Ayla knows it came from
// the vault. What the vault does follows iOS (VaultScreen).
definePageMeta({ showsChats: true });
useHead({ title: `${VAULT_TITLE} - PAVE` });

const conversation = useAylaConversation();
// While the vault shows, the title has no background: the vault scrolls on underneath it.
const showsVault = computed(() => conversation.state.value.messages.length === 0);

onMounted(() => conversation.startNew());
</script>

<template>
  <div class="relative flex min-h-0 flex-1 flex-col">
    <!-- The title sits in the middle, as on every page; the vault scrolls on underneath it. -->
    <AylaTitleBar :class="showsVault ? 'pointer-events-none absolute inset-x-0 top-0 z-10 [&_a,&_button]:pointer-events-auto' : ''" />
    <AylaChatView screen="vault">
      <template #empty>
        <VaultLibrary />
      </template>
    </AylaChatView>
  </div>
</template>
