<script setup lang="ts">
// Asked here, by choice, and not on its own (iOS NotificationsScreen alertsCard): the browser shows its question only
// after "Zet aan". When the browser blocks PAVE, it says where to change that. "Niet nu" hides it for a week.
const alerts = useNotificationAlerts();
const isBlocked = computed(() => alerts.permission.value === 'denied');
const isShown = computed(() => alerts.permission.value !== 'unsupported' && !alerts.isEnabled.value && !alerts.isCardDismissed.value);
</script>

<template>
  <div v-if="isShown" class="flex flex-wrap items-center gap-2.75 rounded-2xl border border-card-line bg-white p-2.5">
    <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-tint text-brand" aria-hidden="true">
      <LayoutPaveIcon name="bell" class="size-4.5" />
    </span>
    <span class="flex min-w-0 flex-1 flex-col gap-0.5">
      <span class="text-sm font-medium text-heading">{{ isBlocked ? ALERTS_CARD_BLOCKED_TITLE : ALERTS_CARD_TITLE }}</span>
      <span class="text-xs text-subtle">{{ isBlocked ? ALERTS_CARD_BLOCKED_MESSAGE : ALERTS_CARD_MESSAGE }}</span>
    </span>
    <span class="flex shrink-0 gap-1">
      <button
        type="button"
        class="min-h-9 rounded-lg px-2.5 text-sm font-medium text-subtle hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="alerts.dismissCard()"
      >
        {{ ALERTS_CARD_DISMISS }}
      </button>
      <button
        v-if="!isBlocked"
        type="button"
        class="min-h-9 rounded-lg px-2.5 text-sm font-semibold text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
        @click="alerts.setEnabled(true)"
      >
        {{ ALERTS_CARD_TURN_ON }}
      </button>
    </span>
  </div>
</template>
