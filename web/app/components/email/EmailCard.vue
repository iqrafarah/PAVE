<script setup lang="ts">
// "Je e-mail ook hier?" in Meldingen (iOS NotificationsScreen.emailCard): offered once; the toolbar always has E-mail.
const STORAGE_KEY = 'pave-email-card-dismissed';

const emit = defineEmits<{
  connect: [];
}>();

const isDismissed = ref(true);

onMounted(() => {
  try {
    isDismissed.value = localStorage.getItem(STORAGE_KEY) === '1';
  } catch {
    isDismissed.value = false;
  }
});

function dismiss() {
  isDismissed.value = true;
  try {
    localStorage.setItem(STORAGE_KEY, '1');
  } catch {
    // Without storage it comes back next time; that is all.
  }
}
</script>

<template>
  <div v-if="!isDismissed" class="flex items-center gap-3 rounded-2xl border border-card-line bg-white p-2.5 pl-3">
    <NotificationKindIcon kind="email" />
    <span class="flex min-w-0 flex-1 flex-col gap-0.5">
      <span class="text-sm font-medium text-heading">{{ EMAIL_CARD_TITLE }}</span>
      <span class="text-xs text-subtle">{{ EMAIL_CARD_MESSAGE }}</span>
    </span>
    <button
      type="button"
      class="min-h-9 rounded-field px-3 text-sm font-semibold text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('connect')"
    >
      {{ EMAIL_CARD_CONNECT }}
    </button>
    <button
      type="button"
      :aria-label="EMAIL_CARD_DISMISS"
      :title="EMAIL_CARD_DISMISS"
      class="flex size-8 items-center justify-center rounded-lg text-subtle hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
      @click="dismiss"
    >
      <LayoutPaveIcon name="xMark" class="size-3.5" />
    </button>
  </div>
</template>
