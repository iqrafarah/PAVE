<script setup lang="ts">
definePageMeta({ showsChats: true });

const route = useRoute();
const conversation = useAylaConversation();
const chats = useAylaChats();

const conversationId = computed(() => String(route.params.id));
const loadStatus = computed(() => conversation.state.value.loadStatus);
const title = computed(() => {
  const found = chats.state.value.conversations.find((item) => item.id === conversationId.value);
  return found?.title ?? AYLA_NAME;
});

useHead({ title: () => `${title.value} - PAVE` });

function load() {
  conversation.open(conversationId.value);
}

// The chat history only opens with the PAVE logo, so the chat keeps whatever the user chose.
onMounted(load);
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <AylaTitleBar />

    <AylaDataLoader v-if="loadStatus === 'loading' || loadStatus === 'idle'" />
    <div v-else-if="loadStatus === 'notFound'" class="mx-auto w-full max-w-xl flex-1 px-4 py-10">
      <AylaNotice :message="AYLA_CONVERSATION_GONE" :action-label="AYLA_NEW_CHAT" action-to="/" />
    </div>
    <div v-else-if="loadStatus === 'failed'" class="mx-auto w-full max-w-xl flex-1 px-4 py-10">
      <AylaNotice :message="AYLA_ERROR_LOADING_CHAT" :action-label="AYLA_RETRY" @action="load" />
    </div>
    <AylaChatView v-else>
      <template #empty>
        <p class="flex flex-1 items-center justify-center px-4 text-sm text-muted">{{ AYLA_NO_MESSAGES }}</p>
      </template>
    </AylaChatView>
  </div>
</template>
