<script setup lang="ts">
import type { PaveNotification } from '~/types/notifications';

// A new notification while PAVE is open (iOS NotificationBanner): a small card at the top that opens Meldingen when
// clicked and goes away by itself after 5 seconds, or with ✕. Hovering or focusing it keeps it, so it can be read.
const props = defineProps<{
  notification: PaveNotification;
}>();

const emit = defineEmits<{
  open: [];
  dismiss: [];
}>();

const SHOW_MS = 5000;
let timer: ReturnType<typeof setTimeout> | undefined;
const detail = computed(() => notificationDetail(props.notification) || NOTIFICATIONS_NEW);

function schedule() {
  clearTimeout(timer);
  timer = setTimeout(() => emit('dismiss'), SHOW_MS);
}

function hold() {
  clearTimeout(timer);
}

watch(() => props.notification.id, schedule, { immediate: true });
onBeforeUnmount(() => clearTimeout(timer));
</script>

<template>
  <div
    role="status"
    class="fixed inset-x-4 top-4 z-60 mx-auto flex max-w-105 items-center gap-1 rounded-2xl border border-card-line bg-white p-1.5 shadow-lg"
    @mouseenter="hold"
    @mouseleave="schedule"
    @focusin="hold"
    @focusout="schedule"
  >
    <button
      type="button"
      :aria-label="NOTIFICATIONS_NEW_LABEL(notification.title)"
      class="flex min-w-0 flex-1 items-center gap-2.75 rounded-xl p-1.5 text-left hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('open')"
    >
      <NotificationKindIcon :kind="notification.kind" />
      <span class="flex min-w-0 flex-1 flex-col gap-0.5">
        <span class="truncate text-sm font-semibold text-heading">{{ notification.title }}</span>
        <span class="truncate text-xs text-subtle">{{ detail }}</span>
      </span>
    </button>
    <button
      type="button"
      :aria-label="NOTIFICATIONS_CLOSE"
      class="flex size-9 shrink-0 items-center justify-center rounded-lg text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('dismiss')"
    >
      <LayoutIcon name="close" class="size-4" />
    </button>
  </div>
</template>
