<script setup lang="ts">
import type { RowMenuItem } from '~/types/ayla';

definePageMeta({ showsChats: true });
useHead({ title: `${AYLA_LOCKED_CHATS} - PAVE` });

const lock = useAylaChatLock();
const chats = useAylaChats();

const pinError = ref<string | null>(null);
const isBusy = ref(false);
const isAskingPin = ref(false);
const actionError = ref<string | null>(null);
const resetRef = useTemplateRef<{ open: () => void }>('reset');

const isUnlocked = computed(() => lock.state.value.isUnlocked);
const lockedChats = computed(() =>
  chats.state.value.conversations
    .filter((conversation) => lock.isLocked(conversation.id))
    .sort((first, second) => second.updatedAt.localeCompare(first.updatedAt)),
);
const menuItems: RowMenuItem[] = [{ id: 'unlock', label: AYLA_UNLOCK_MENU }];

async function check(pin: string) {
  isBusy.value = true;
  pinError.value = null;
  const result = await lock.checkPin(pin);
  isBusy.value = false;
  if (result === 'right') isAskingPin.value = false;
  else pinError.value = { wrong: AYLA_PIN_WRONG, blocked: AYLA_PIN_BLOCKED, failed: AYLA_PINCODE_FAILED }[result];
}

async function unlock(id: string) {
  actionError.value = null;
  const { isFailed } = await lock.unlockChat(id);
  if (isFailed) actionError.value = AYLA_UNLOCK_FAILED;
}

async function reset() {
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
  if (lock.state.value.status === 'idle') await lock.load();
  if (!lock.state.value.isUnlocked) isAskingPin.value = true;
});
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <AylaTitleBar :shows-title="false" />

    <div class="flex-1 overflow-y-auto px-4 py-8">
      <div v-if="isUnlocked" class="mx-auto w-full max-w-135">
        <div class="flex items-center gap-3">
          <span class="flex size-10.75 shrink-0 items-center justify-center rounded-xl bg-tint text-brand">
            <LayoutPaveIcon name="lockOpen" class="size-5" />
          </span>
          <h1 class="min-w-0 flex-1 truncate font-heading text-xl font-semibold text-heading">{{ AYLA_LOCKED_CHATS }}</h1>
          <button
            type="button"
            class="flex items-center gap-2 rounded-pill border border-line px-4 py-2 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
            @click="lock.relock"
          >
            <LayoutPaveIcon name="lock" class="size-4 text-brand" />
            {{ AYLA_LOCKED_RELOCK }}
          </button>
        </div>
        <button
          type="button"
          class="mt-6 flex w-full items-center gap-3 rounded-pill border border-line px-5 py-3.5 text-left text-sm text-subtle hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="lock.startLockedChat"
        >
          <LayoutIcon name="plus" class="size-4 text-brand" />
          {{ AYLA_LOCKED_CHIP }}
        </button>
        <p v-if="actionError" role="alert" class="mt-3 text-sm text-danger">{{ actionError }}</p>

        <p v-if="!lockedChats.length" class="mt-6 text-sm text-subtle">{{ AYLA_LOCKED_EMPTY }}</p>
        <ul v-else class="mt-6 space-y-0.5">
          <li v-for="chat in lockedChats" :key="chat.id" class="group -mx-2 flex items-center rounded-md hover:bg-surface">
            <NuxtLink
              :to="`/ayla/${chat.id}`"
              class="min-w-0 flex-1 truncate rounded-md px-2 py-1 text-sm font-medium text-heading focus-visible:outline-2 focus-visible:outline-brand"
            >
              {{ chat.title }}
            </NuxtLink>
            <AylaRowMenu
              :items="menuItems"
              :label="`${AYLA_MORE_OPTIONS}: ${chat.title}`"
              @select="unlock(chat.id)"
            />
          </li>
        </ul>
      </div>
      <p v-else-if="lock.state.value.status === 'unavailable'" class="mx-auto max-w-135 text-sm text-subtle">
        {{ AYLA_PINCODE_FAILED }}
      </p>
    </div>

    <AylaPinDialog
      v-if="isAskingPin && lock.state.value.hasPin"
      mode="enter"
      :error="pinError"
      :is-busy="isBusy"
      @complete="check"
      @forgot="resetRef?.open()"
      @close="cancelPin"
    />
    <LayoutConfirmSheet
      ref="reset"
      :title="AYLA_PIN_RESET_QUESTION"
      :message="AYLA_PIN_RESET_BODY"
      :confirm-label="AYLA_PIN_RESET_CONFIRM"
      @confirm="reset"
    />
  </div>
</template>
