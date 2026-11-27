<script setup lang="ts">
import type { NotificationEntry } from '~/types/notifications';

// One row of the list beside the opened notification, like a mail inbox (iOS NotificationInboxRow): a coloured icon, the
// title in bold while unread, who or what it is about ("Ayla · 3 berichten" for a chat) and when. "Markeer als gelezen"
// and "Verwijderen" appear on hover and keyboard focus. In "Recent verwijderd" the hint says how long it can come back.
const props = defineProps<{
  entry: NotificationEntry;
  hint?: string;
  isSelected?: boolean;
  isTrash?: boolean;
}>();

const emit = defineEmits<{
  open: [];
  action: [id: 'read' | 'delete'];
}>();

const notification = computed(() => props.entry.notification);
const isUnread = computed(() => props.entry.isUnread && !props.isTrash);
const subtitle = computed(() => entrySubtitle(props.entry));
const time = computed(() => notificationTime(notification.value.date));
// An e-mail's people and subject, and the title of a chat, are what people wrote: never translated.
const isOwnText = computed(() => notification.value.kind === 'email' || notification.value.kind === 'conversation');

const actionButton =
  'flex size-8 items-center justify-center rounded-lg text-subtle hover:bg-tint hover:text-heading focus-visible:outline-2 focus-visible:outline-brand';
</script>

<template>
  <div class="group relative">
    <button
      type="button"
      data-notification-row
      :aria-current="isSelected ? 'true' : undefined"
      :class="isSelected ? 'bg-tint' : 'hover:bg-surface'"
      class="flex w-full items-start gap-3 rounded-xl px-3 py-3 text-left focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand"
      @click="emit('open')"
    >
      <NotificationKindIcon :kind="notification.kind" class="mt-0.5" />
      <span class="min-w-0 flex-1">
        <span :translate="isOwnText ? 'no' : undefined" :class="isUnread ? 'font-semibold' : 'font-medium'" class="line-clamp-2 text-sm text-heading">
          {{ notification.title }}
        </span>
        <span v-if="subtitle" :translate="notification.kind === 'email' ? 'no' : undefined" class="mt-0.5 block truncate text-xs text-subtle">{{ subtitle }}</span>
        <span v-if="hint" class="mt-1 block text-xs font-medium text-brand">{{ hint }}</span>
      </span>
      <span class="flex shrink-0 flex-col items-end gap-1.5 group-hover:invisible group-focus-within:invisible">
        <time :datetime="notification.date" :class="isUnread ? 'text-brand' : 'text-subtle'" class="text-xs">{{ time }}</time>
        <span v-if="isUnread" class="size-2 rounded-full bg-brand">
          <span class="sr-only">{{ NOTIFICATIONS_UNREAD }}</span>
        </span>
      </span>
    </button>

    <div
      v-if="!isTrash"
      class="absolute right-2 top-2 flex gap-0.5 rounded-lg bg-white opacity-0 shadow-sm transition-opacity group-hover:opacity-100 group-focus-within:opacity-100 [@media(hover:none)]:hidden"
    >
      <button
        v-if="isUnread"
        type="button"
        :aria-label="`${NOTIFICATIONS_MARK_READ}: ${notification.title}`"
        :title="NOTIFICATIONS_MARK_READ"
        :class="actionButton"
        @click="emit('action', 'read')"
      >
        <LayoutPaveIcon name="mailOpen" class="size-4" />
      </button>
      <button
        type="button"
        :aria-label="`${NOTIFICATIONS_DELETE}: ${notification.title}`"
        :title="NOTIFICATIONS_DELETE"
        :class="actionButton"
        class="hover:text-danger"
        @click="emit('action', 'delete')"
      >
        <LayoutPaveIcon name="trash" class="size-4" />
      </button>
    </div>
  </div>
</template>
