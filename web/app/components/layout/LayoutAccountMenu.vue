<script setup lang="ts">
// Your account at the bottom of the menu (iOS MainAccountMenu): your photo, or the first letter of your name when
// there is no photo. Click it for your settings or to sign out.
withDefaults(
  defineProps<{
    // Which way the list opens from the badge: right of it in the rail, left of it in the drawer.
    align?: 'start' | 'end';
  }>(),
  { align: 'start' },
);

const account = useAccount();
const { signOut } = useAuth();

const isOpen = ref(false);
const rootRef = useTemplateRef<HTMLDivElement>('root');
const toggleRef = useTemplateRef<HTMLButtonElement>('toggle');
const confirmRef = useTemplateRef<{ open: () => void }>('confirm');
const menuId = useId();

function getItems() {
  return Array.from(rootRef.value?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);
}

async function open() {
  isOpen.value = true;
  await nextTick();
  getItems()[0]?.focus();
}

function close(isReturningFocus: boolean) {
  isOpen.value = false;
  if (isReturningFocus) toggleRef.value?.focus();
}

function askSignOut() {
  close(false);
  confirmRef.value?.open();
}

function handleKeydown(event: KeyboardEvent) {
  if (!isOpen.value) return;
  const items = getItems();
  const index = items.findIndex((item) => item === document.activeElement);
  if (event.key === 'Escape') close(true);
  else if (event.key === 'ArrowDown') items[(index + 1) % items.length]?.focus();
  else if (event.key === 'ArrowUp') items[(index - 1 + items.length) % items.length]?.focus();
  else return;
  event.preventDefault();
  event.stopPropagation();
}

function handleFocusOut(event: FocusEvent) {
  if (!rootRef.value?.contains(event.relatedTarget as Node | null)) isOpen.value = false;
}

onMounted(account.load);
</script>

<template>
  <div ref="root" class="relative" @focusout="handleFocusOut" @keydown="handleKeydown">
    <button
      ref="toggle"
      type="button"
      aria-haspopup="menu"
      :aria-expanded="isOpen"
      :aria-controls="isOpen ? menuId : undefined"
      :aria-label="MENU_ACCOUNT"
      class="flex rounded-full hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="isOpen ? close(false) : open()"
    >
      <SettingsAccountBadge :name="account.state.value.fullName" :avatar-url="account.state.value.avatarUrl" />
    </button>
    <div
      v-if="isOpen"
      :id="menuId"
      role="menu"
      :aria-label="MENU_ACCOUNT"
      :class="align === 'start' ? 'left-0' : 'right-0'"
      class="absolute bottom-full z-50 mb-2 w-56 rounded-2xl border border-card-border bg-white p-1.5 shadow-lg"
    >
      <p v-if="account.state.value.fullName" class="truncate px-3 py-2 text-xs font-medium text-subtle">
        {{ account.state.value.fullName }}
      </p>
      <NuxtLink
        to="/instellingen"
        role="menuitem"
        class="flex min-h-11 items-center gap-3 rounded-xl px-3 text-base text-heading hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="close(false)"
      >
        <LayoutPaveIcon name="settings" class="size-5" />
        {{ SETTINGS_TITLE }}
      </NuxtLink>
      <button
        type="button"
        role="menuitem"
        class="flex min-h-11 w-full items-center gap-3 rounded-xl px-3 text-left text-base text-danger hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="askSignOut"
      >
        <LayoutPaveIcon name="signOut" class="size-5" />
        {{ SETTINGS_SIGN_OUT }}
      </button>
    </div>
    <LayoutConfirmSheet
      ref="confirm"
      :title="SETTINGS_SIGN_OUT_QUESTION"
      :confirm-label="SETTINGS_SIGN_OUT"
      @confirm="signOut"
    />
  </div>
</template>
