<script setup lang="ts">
import type { NotificationKind, NotificationTab } from '~/types/notifications';

// The bar above the inbox, in the style of the vault's toolbar: Alle and Ongelezen, Soort, search, "Alles gelezen"
// and "Recent verwijderd". With e-mail: "Nieuw bericht" once a mailbox is connected, and E-mail to connect one.
const props = defineProps<{
  kinds: NotificationKind[];
  totalCount: number;
  unreadCount: number;
  trashCount: number;
  hasEmail?: boolean;
}>();

const tab = defineModel<NotificationTab>('tab', { required: true });
const kind = defineModel<NotificationKind | null>('kind', { required: true });
const searchText = defineModel<string>('searchText', { required: true });

const emit = defineEmits<{
  markAllRead: [];
  openTrash: [];
  compose: [];
  openEmail: [];
}>();

const searchId = useId();
const kindOptions = computed(() => [
  { id: '', label: NOTIFICATIONS_FILTER_ALL_KINDS, isChecked: kind.value === null },
  ...props.kinds.map((entry) => ({ id: entry, label: NOTIFICATION_KIND_TITLES[entry], isChecked: kind.value === entry })),
]);
const tabs = computed(() => [
  { id: 'all' as const, label: NOTIFICATIONS_TAB_ALL, count: props.totalCount },
  { id: 'unread' as const, label: NOTIFICATIONS_UNREAD, count: props.unreadCount },
]);

function chooseKind(id: string) {
  kind.value = (id || null) as NotificationKind | null;
}

const textButton =
  'flex h-9 items-center gap-2 rounded-lg px-2.5 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand disabled:text-subtle disabled:hover:bg-transparent';
const filterTab = 'flex h-9 items-center gap-1 rounded-lg px-2.5 text-[0.9375rem] font-medium text-heading focus-visible:outline-2 focus-visible:outline-brand';
</script>

<template>
  <div class="flex flex-wrap items-center justify-between gap-x-6 gap-y-3">
    <div class="flex flex-wrap items-center gap-1.5">
      <button
        v-for="option in tabs"
        :key="option.id"
        type="button"
        :aria-pressed="tab === option.id"
        :class="[filterTab, tab === option.id ? 'bg-tint' : 'hover:bg-surface']"
        @click="tab = option.id"
      >
        {{ option.label }}
        <span class="min-w-5 rounded-full bg-white px-1.5 text-center text-xs text-subtle">{{ option.count }}</span>
      </button>
      <VaultMenu
        class="ml-1.5"
        :label="NOTIFICATIONS_FILTER_TYPE"
        :options="kindOptions"
        :summary="kind ? NOTIFICATION_KIND_TITLES[kind] : undefined"
        :toggle-class="[filterTab, kind ? 'bg-tint' : 'hover:bg-surface'].join(' ')"
        @select="chooseKind"
      >
        <template #label>
          {{ kind ? NOTIFICATION_KIND_TITLES[kind] : NOTIFICATIONS_FILTER_TYPE }}
          <LayoutIcon name="chevronDown" class="size-3.5" />
        </template>
      </VaultMenu>
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
      <button type="button" :class="textButton" @click="emit('openEmail')">
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
