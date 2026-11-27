<script setup lang="ts">
import type { PaveNotification, ReviewOutcome } from '~/types/notifications';

// The opened notification, in the pane beside the inbox (on a small screen in its place, with a way back). The head
// says what it is, from whom and when; the body depends on the kind.
const props = defineProps<{
  notification: PaveNotification;
  onResolved?: (outcome: ReviewOutcome) => void;
}>();

const emit = defineEmits<{
  back: [];
  delete: [];
  openItem: [itemId: string];
}>();

const received = computed(() =>
  new Date(props.notification.date).toLocaleString('nl-NL', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }),
);
const subject = computed(() => props.notification.documentName);
// Who asked, at which organisation, for a verification request; otherwise who it is from.
const from = computed(() => {
  const { learnerName, learnerOrganization, personName } = props.notification;
  return learnerName ? [learnerName, learnerOrganization].filter(Boolean).join(', ') : personName;
});
</script>

<template>
  <article class="flex min-h-full flex-col" :aria-labelledby="`notification-${notification.id}`">
    <header class="border-b border-card-line px-6 pb-5 pt-5">
      <div class="flex items-center justify-between gap-3">
        <button
          type="button"
          class="-ml-2 flex h-8 items-center gap-2 rounded-lg px-2 text-sm font-medium text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand lg:hidden"
          @click="emit('back')"
        >
          <VaultIcon src="/images/vault/icons/ArrowLeft.svg" class="size-4" />
          {{ NOTIFICATIONS_BACK }}
        </button>
        <span class="rounded-md bg-surface px-2 py-0.5 text-xs font-medium text-subtle max-lg:hidden">
          {{ NOTIFICATION_KIND_TITLES[notification.kind] }}
        </span>
        <button
          type="button"
          :title="NOTIFICATIONS_DELETE"
          :aria-label="NOTIFICATIONS_DELETE"
          class="flex size-9 items-center justify-center rounded-lg text-subtle hover:bg-status-rejected-surface hover:text-danger focus-visible:outline-2 focus-visible:outline-brand"
          @click="emit('delete')"
        >
          <LayoutPaveIcon name="trash" class="size-4.5" />
        </button>
      </div>
      <div class="mt-3 flex items-start gap-4">
        <NotificationKindIcon :kind="notification.kind" size="large" />
        <div class="min-w-0">
          <h2 :id="`notification-${notification.id}`" class="font-heading text-xl font-semibold text-heading">
            {{ notification.title }}<span v-if="subject" class="font-normal text-subtle">: {{ subject }}</span>
          </h2>
          <p class="mt-1 text-sm text-subtle">
            {{ NOTIFICATIONS_FROM }} <span class="font-medium text-heading">{{ from }}</span>
            · {{ NOTIFICATIONS_RECEIVED(received) }}
          </p>
        </div>
      </div>
    </header>

    <NotificationReviewPanel
      v-if="notification.kind === 'verification_request'"
      :notification="notification"
      :on-resolved="onResolved"
      class="flex-1"
    />
    <NotificationEvidencePanel
      v-else-if="notification.kind === 'evidence_verified' || notification.kind === 'evidence_rejected'"
      :notification="notification"
      @open-item="emit('openItem', $event)"
    />
    <div v-else class="flex flex-col items-start gap-4 p-6">
      <p class="text-sm text-heading">{{ NOTIFICATION_CONVERSATION_MESSAGE }}</p>
      <NuxtLink
        v-if="notification.conversationId"
        :to="`/ayla/${notification.conversationId}`"
        class="inline-flex min-h-10 items-center gap-2 rounded-field bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      >
        <LayoutPaveIcon name="chat" class="size-4.5" />
        {{ NOTIFICATION_OPEN_CONVERSATION }}
      </NuxtLink>
    </div>
  </article>
</template>
