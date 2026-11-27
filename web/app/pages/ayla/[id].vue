<script setup lang="ts">
definePageMeta({ showsChats: true });

const route = useRoute();
const conversation = useAylaConversation();
const chats = useAylaChats();
const lock = useAylaChatLock();

const conversationId = computed(() => String(route.params.id));
// A locked chat opens only after the PIN of the account was entered in this tab.
const isGated = computed(() => lock.isLocked(conversationId.value) && !lock.state.value.isUnlocked);
const pinError = ref<string | null>(null);
const isChecking = ref(false);
const loadStatus = computed(() => conversation.state.value.loadStatus);
const title = computed(() => {
  const found = chats.state.value.conversations.find((item) => item.id === conversationId.value);
  return found?.title ?? AYLA_NAME;
});

useHead({ title: () => `${title.value} - PAVE` });

// An open locked chat offers to unlock it: it then goes back to the normal chat list.
const isOpenLocked = computed(() => lock.isLocked(conversationId.value) && lock.state.value.isUnlocked);
const unlockError = ref<string | null>(null);

async function unlock() {
  unlockError.value = null;
  const { isFailed } = await lock.unlockChat(conversationId.value);
  if (isFailed) unlockError.value = AYLA_UNLOCK_FAILED;
}

// "Pincode vergeten?": after the warning the locked chats and the PIN are deleted, and the start screen opens.
const resetRef = useTemplateRef<{ open: () => void }>('resetConfirm');

async function resetPin() {
  const { isFailed } = await lock.resetPin();
  if (isFailed) pinError.value = AYLA_PINCODE_FAILED;
  else await navigateTo('/');
}

function load() {
  conversation.open(conversationId.value);
}

// The chat history only opens with the PAVE logo, so the chat keeps whatever the user chose.
async function checkPin(pin: string) {
  isChecking.value = true;
  pinError.value = null;
  const result = await lock.checkPin(pin);
  isChecking.value = false;
  if (result !== 'right') pinError.value = { wrong: AYLA_PIN_WRONG, blocked: AYLA_PIN_BLOCKED, failed: AYLA_PINCODE_FAILED, right: '' }[result];
}

onMounted(async () => {
  // The lock list comes before the chat, so a locked chat is never shown before the PIN.
  if (lock.state.value.status === 'idle') await lock.load();
  load();
});

// The chat on screen gives no notification for Ayla's answers in it, and one about it is read at once (iOS keepsOpenChat).
// A locked chat counts once it is unlocked.
const notifications = useNotifications();
let releaseOpenChat: (() => void) | null = null;
watch(
  () => (import.meta.client && !isGated.value ? conversationId.value : null),
  (id) => {
    releaseOpenChat?.();
    releaseOpenChat = id ? notifications.keepOpen(id) : null;
    if (id) {
      const unread = notifications.state.value.notifications.filter((entry) => entry.conversationId === id && entry.isUnread).map((entry) => entry.id);
      notifications.markRead(unread);
    }
  },
  { immediate: true },
);
onBeforeUnmount(() => releaseOpenChat?.());
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <AylaTitleBar>
      <template #end>
        <button
          v-if="isOpenLocked"
          type="button"
          class="flex items-center gap-2 rounded-pill border border-line px-4 py-2 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="unlock"
        >
          <LayoutPaveIcon name="lockOpen" class="size-4 text-brand" />
          {{ AYLA_UNLOCK_CHAT }}
        </button>
      </template>
    </AylaTitleBar>
    <p v-if="unlockError" role="alert" class="px-4 pt-2 text-center text-sm text-danger">{{ unlockError }}</p>

    <AylaPinDialog
      v-if="isGated && lock.state.value.hasPin"
      mode="enter"
      :error="pinError"
      :is-busy="isChecking"
      @complete="checkPin"
      @forgot="resetRef?.open()"
      @close="navigateTo('/')"
    />
    <LayoutConfirmSheet
      ref="resetConfirm"
      :title="AYLA_PIN_RESET_QUESTION"
      :message="AYLA_PIN_RESET_BODY"
      :confirm-label="AYLA_PIN_RESET_CONFIRM"
      @confirm="resetPin"
    />
    <div v-if="isGated" class="flex-1" />
    <AylaDataLoader v-else-if="loadStatus === 'loading' || loadStatus === 'idle'" />
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
