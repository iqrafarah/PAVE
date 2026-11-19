<script setup lang="ts">
definePageMeta({ showsChats: true });
useHead({ title: `${AYLA_LOCKED_CHATS} - PAVE` });

const lock = useAylaChatLock();
const chats = useAylaChats();
const conversation = useAylaConversation();

const pinError = ref<string | null>(null);
const isBusy = ref(false);
const isAskingPin = ref(false);
const actionError = ref<string | null>(null); // set when resetting the PIN fails
const isRecovering = ref(false);
const deleteRef = useTemplateRef<{ open: () => void }>('deleteAll');

const isUnlocked = computed(() => lock.state.value.isUnlocked);
const lockedChats = computed(() =>
  chats.state.value.conversations
    .filter((conversation) => lock.isLocked(conversation.id))
    .sort((first, second) => second.updatedAt.localeCompare(first.updatedAt)),
);

async function check(pin: string) {
  isBusy.value = true;
  pinError.value = null;
  const result = await lock.checkPin(pin);
  isBusy.value = false;
  if (result === 'right') isAskingPin.value = false;
  else pinError.value = { wrong: AYLA_PIN_WRONG, blocked: AYLA_PIN_BLOCKED, failed: AYLA_PINCODE_FAILED }[result];
}

function recovered() {
  isRecovering.value = false;
  isAskingPin.value = false;
}

function recoverFailed() {
  isRecovering.value = false;
  actionError.value = AYLA_PINCODE_FAILED;
}

async function reset() {
  isRecovering.value = false;
  const { isFailed } = await lock.resetPin();
  isAskingPin.value = false;
  if (isFailed) actionError.value = AYLA_PINCODE_FAILED;
  else await navigateTo('/');
}

// Closing the PIN window without the PIN leaves the locked chats: back to the start screen.
async function cancelPin() {
  isAskingPin.value = false;
  await navigateTo('/');
}

onMounted(async () => {
  conversation.startNew();
  if (lock.state.value.status === 'idle') await lock.load();
  if (!lock.state.value.isUnlocked) isAskingPin.value = true;
});
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <AylaChatListPage
      v-if="isUnlocked"
      :title="AYLA_LOCKED_CHATS"
      icon="lockOpen"
      :placeholder="AYLA_LOCKED_CHIP"
      is-locked
      :chats="lockedChats"
      :empty-text="AYLA_LOCKED_EMPTY"
    >
      <template #actions>
        <button
          type="button"
          class="flex shrink-0 items-center gap-2 rounded-pill border border-line px-4 py-2 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="lock.relock"
        >
          <LayoutPaveIcon name="lock" class="size-4 text-brand" />
          {{ AYLA_LOCKED_RELOCK }}
        </button>
      </template>
      <template #notice>
        <p v-if="actionError" role="alert" class="mt-3 text-sm text-danger">{{ actionError }}</p>
      </template>
    </AylaChatListPage>
    <div v-else class="flex min-h-0 flex-1 flex-col">
      <AylaTitleBar :shows-title="false" />
      <p v-if="lock.state.value.status === 'unavailable'" class="mx-auto mt-8 max-w-135 px-4 text-sm text-subtle">
        {{ AYLA_PINCODE_FAILED }}
      </p>
    </div>

    <AylaPinDialog
      v-if="isAskingPin && lock.state.value.hasPin"
      mode="enter"
      :error="pinError"
      :is-busy="isBusy"
      @complete="check"
      @forgot="isRecovering = true"
      @close="cancelPin"
    />
    <AylaPinRecover
      v-if="isRecovering"
      @done="recovered"
      @failed="recoverFailed"
      @close="isRecovering = false"
      @delete-all="deleteRef?.open()"
    />
    <LayoutConfirmSheet
      ref="deleteAll"
      :title="AYLA_PIN_RESET_QUESTION"
      :message="ACCOUNT_PIN_DELETE_BODY"
      :confirm-label="AYLA_PIN_RESET_CONFIRM"
      @confirm="reset"
    />
  </div>
</template>
