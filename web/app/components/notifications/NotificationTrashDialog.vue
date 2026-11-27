<script setup lang="ts">
import type { PaveNotification } from '~/types/notifications';

// "Recent verwijderd" (iOS NotificationTrashScreen): deleted notifications, each restorable for 7 days.
defineProps<{
  notifications: PaveNotification[];
}>();

const isOpen = defineModel<boolean>('open', { required: true });

const emit = defineEmits<{
  restore: [id: string];
}>();
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="NOTIFICATIONS_TRASH" width="narrow">
    <p class="-mt-2 mb-4 text-sm text-subtle">{{ NOTIFICATIONS_TRASH_INTRO }}</p>
    <LayoutEmptyState
      v-if="!notifications.length"
      icon="trash"
      :title="NOTIFICATIONS_TRASH_EMPTY_TITLE"
      :message="NOTIFICATIONS_TRASH_EMPTY_MESSAGE"
      class="py-6"
    />
    <ul v-else class="flex flex-col gap-2 pb-4">
      <li v-for="notification in notifications" :key="notification.id" class="flex items-center gap-2">
        <NotificationRow
          :entry="{ notification, ids: [notification.id], isUnread: false }"
          :hint="NOTIFICATIONS_DAYS_LEFT(daysLeft(notification.deletedAt ?? ''))"
          is-trash
          class="min-w-0 flex-1"
          @open="emit('restore', notification.id)"
        />
        <button
          type="button"
          class="flex min-h-10 shrink-0 items-center gap-1.5 rounded-field px-2.5 text-sm font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
          @click="emit('restore', notification.id)"
        >
          <LayoutIcon name="redo" class="size-4" />
          {{ NOTIFICATIONS_RESTORE }}
        </button>
      </li>
    </ul>
  </VaultSheet>
</template>
