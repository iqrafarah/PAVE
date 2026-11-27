<script setup lang="ts">
import type { NotificationTab } from '~/types/notifications';

// The bar above the inbox, in the style of the vault's toolbar: the tabs Alles, Gesprekken, Werk and Bewijs (as on
// iOS), search, "Alles gelezen" and "Recent verwijderd". With e-mail: "Nieuw bericht" once a mailbox is connected, and
// E-mail to connect one.
defineProps<{
  unreadCount: number;
  trashCount: number;
  hasEmail?: boolean;
  showsEmail?: boolean;
}>();

const tab = defineModel<NotificationTab>('tab', { required: true });
const searchText = defineModel<string>('searchText', { required: true });

const emit = defineEmits<{
  markAllRead: [];
  openTrash: [];
  compose: [];
  openEmail: [];
}>();

const searchId = useId();
const TABS: NotificationTab[] = ['all', 'conversations', 'applications', 'evidence'];

const textButton =
  'flex h-9 items-center gap-2 rounded-lg px-2.5 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand disabled:text-subtle disabled:hover:bg-transparent';
const filterTab = 'flex h-9 items-center gap-1 rounded-lg px-2.5 text-[0.9375rem] font-medium text-heading focus-visible:outline-2 focus-visible:outline-brand';
</script>

<template>
  <div class="flex flex-wrap items-center justify-between gap-x-6 gap-y-3">
    <div class="flex flex-wrap items-center gap-1.5" role="group" :aria-label="NOTIFICATION_TABS_LABEL">
      <button
        v-for="option in TABS"
        :key="option"
        type="button"
        :aria-pressed="tab === option"
        :class="[filterTab, tab === option ? 'bg-tint' : 'hover:bg-surface']"
        @click="tab = option"
      >
        {{ NOTIFICATION_TABS[option] }}
      </button>
    </div>

    <div class="flex flex-wrap items-center gap-1.5">
      <label :for="searchId" class="flex h-9 w-64 items-center gap-2 rounded-field border border-toolbar-line bg-surface px-2.5 has-focus-visible:border-brand max-sm:w-full">
        <LayoutPaveIcon name="search" class="size-4 shrink-0 text-subtle" />
        <span class="sr-only">{{ NOTIFICATIONS_SEARCH }}</span>
        <input :id="searchId" v-model="searchText" type="search" :placeholder="NOTIFICATIONS_SEARCH" class="min-w-0 flex-1 bg-transparent text-sm text-heading outline-none placeholder:text-subtle" />
      </label>
      <button v-if="hasEmail" type="button" :class="textButton" @click="emit('compose')">
        <LayoutPaveIcon name="compose" class="size-4" />
        {{ EMAIL_NEW_MESSAGE }}
      </button>
      <button v-if="showsEmail" type="button" :class="textButton" @click="emit('openEmail')">
        <VaultIcon src="/images/notifications/envelope.svg" class="size-4" />
        {{ EMAIL_ACCOUNT_BUTTON }}
      </button>
      <button type="button" :class="textButton" :disabled="!unreadCount" :title="NOTIFICATIONS_MARK_ALL_READ_LABEL" @click="emit('markAllRead')">
        <LayoutPaveIcon name="mailOpen" class="size-4" />
        {{ NOTIFICATIONS_MARK_ALL_READ }}
      </button>
      <button v-if="trashCount" type="button" :class="textButton" @click="emit('openTrash')">
        <LayoutPaveIcon name="trash" class="size-4" />
        {{ NOTIFICATIONS_TRASH }}
        <span class="text-xs text-subtle">{{ trashCount }}</span>
      </button>
    </div>
  </div>
</template>
