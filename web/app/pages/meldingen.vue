<script setup lang="ts">
import type { NotificationEntry, NotificationTab, ReviewOutcome } from '~/types/notifications';

// The inbox as on a desktop mail app: the list on the left, the opened notification on the right (on a small screen one
// at a time). Which one is open is in the address (?melding=), so the back button and a link from the banner work.
// As on iOS: a chat opens straight away, deleting moves a notification to "Recent verwijderd" for 7 days, and after
// judging a request the list comes back with what was done. The conversations of a connected mailbox (useEmail) are
// rows of the same list; one opens as a chat in the pane beside it.
useHead({ title: `${NOTIFICATIONS_TITLE} - PAVE` });

const UNDO_MS = 5000;
const RESOLVED_MS = 4000;
const QUERY_KEY = 'melding';

const route = useRoute();
const router = useRouter();
const notifications = useNotifications();
const vault = useVault();
const fair = useFairInvitations();
const email = useEmail();
const isEmailOpen = ref(false);
const isComposeOpen = ref(false);
const tab = ref<NotificationTab>('all');
const searchText = ref('');
const isTrashOpen = ref(false);
const openedItemId = ref<string | null>(null);
const editedItemId = ref<string | null>(null);
// The notifications just deleted (a chat with several is one row), while "Ongedaan maken" is on screen.
const undoIds = ref<string[]>([]);
const resolved = ref<string | null>(null);
const problem = ref<string | null>(null);
let undoTimer: ReturnType<typeof setTimeout> | undefined;
let resolvedTimer: ReturnType<typeof setTimeout> | undefined;

const state = computed(() => notifications.state.value);
const inbox = computed(() => [...inboxOf(state.value.notifications), ...email.threads.value.map(threadAsNotification)]);
const kinds = computed(() => availableKinds(state.value.audience, inbox.value));
const shownInbox = computed(() => applyNotificationFilter(inbox.value, kinds.value, { tab: 'all', searchText: '' }));
const visible = computed(() =>
  applyNotificationFilter(inbox.value, kinds.value, { tab: tab.value, searchText: searchText.value }),
);
const sections = computed(() => groupEntries(visible.value));
const unreadCount = computed(() => shownInbox.value.filter((entry) => entry.isUnread).length);
const trash = computed(() => trashOf(state.value.notifications));
const isFiltered = computed(() => Boolean(searchText.value.trim()));
/** The fair's invitations above the list, under Alles and Werk, while not searching (iOS). */
const showsFair = computed(() => !isFiltered.value && tabShowsApplications(tab.value) && fair.shown.value.length > 0);
/** "Je bent helemaal bij", or what the tab is for. */
const emptyText = computed(() => {
  switch (tab.value) {
    case 'conversations':
      return {
        title: NOTIFICATIONS_EMPTY_CONVERSATIONS_TITLE,
        message: email.hasAccount.value ? NOTIFICATIONS_EMPTY_CONVERSATIONS_MESSAGE : NOTIFICATIONS_EMPTY_CONVERSATIONS_NO_ACCOUNT,
      };
    case 'applications':
      return { title: NOTIFICATIONS_EMPTY_APPLICATIONS_TITLE, message: NOTIFICATIONS_EMPTY_APPLICATIONS_MESSAGE };
    case 'evidence':
      return { title: NOTIFICATIONS_EMPTY_EVIDENCE_TITLE, message: NOTIFICATIONS_EMPTY_MESSAGE[state.value.audience] };
    default:
      return { title: NOTIFICATIONS_EMPTY_TITLE, message: NOTIFICATIONS_EMPTY_MESSAGE[state.value.audience] };
  }
});
const selectedId = computed(() => (typeof route.query[QUERY_KEY] === 'string' ? route.query[QUERY_KEY] : null));
const selected = computed(() => inbox.value.find((entry) => entry.id === selectedId.value) ?? null);

/** E-mail rows are read in the mailbox, the rest in PAVE. */
function markEntriesRead(ids: string[]) {
  for (const id of ids.filter(isEmailEntryId)) email.markRead(threadIdOf(id));
  const rest = ids.filter((id) => !isEmailEntryId(id));
  if (rest.length) notifications.markRead(rest);
}

function markAllRead() {
  notifications.markAllRead();
  for (const thread of email.threads.value) if (isThreadUnread(thread)) email.markRead(thread.id);
}

function select(id: string | null) {
  const query = { ...route.query };
  if (id) query[QUERY_KEY] = id;
  else delete query[QUERY_KEY];
  router.replace({ query });
}

/** A chat opens straight away, as on iOS; everything else in the pane beside the list. */
function open(entry: NotificationEntry) {
  problem.value = null;
  markEntriesRead(entry.ids);
  const { notification } = entry;
  if (notification.kind === 'conversation' && notification.conversationId) {
    navigateTo(`/ayla/${notification.conversationId}`);
    return;
  }
  select(notification.id);
}

async function remove(ids: string[]) {
  problem.value = null;
  if (selectedId.value && ids.includes(selectedId.value)) select(null);
  clearTimeout(undoTimer);
  undoIds.value = ids;
  undoTimer = setTimeout(() => (undoIds.value = []), UNDO_MS);
  // An e-mail conversation goes to the bin of the mailbox once "Ongedaan maken" is gone.
  for (const id of ids.filter(isEmailEntryId)) email.deleteThread(threadIdOf(id), () => (problem.value = EMAIL_DELETE_FAILED));
  const rest = ids.filter((id) => !isEmailEntryId(id));
  if (!rest.length) return;
  const { isFailed } = await notifications.setDeleted(rest, true);
  if (!isFailed) return;
  problem.value = NOTIFICATIONS_DELETE_FAILED;
  undoIds.value = undoIds.value.filter((id) => !ids.includes(id));
}

async function restore(ids: string[]) {
  problem.value = null;
  const { isFailed } = await notifications.setDeleted(ids, false);
  if (isFailed) problem.value = NOTIFICATIONS_RESTORE_FAILED;
}

function undo() {
  const ids = undoIds.value;
  clearTimeout(undoTimer);
  undoIds.value = [];
  for (const id of ids.filter(isEmailEntryId)) email.undoDelete(threadIdOf(id));
  const rest = ids.filter((id) => !isEmailEntryId(id));
  if (rest.length) restore(rest);
}

function handleAction(entry: NotificationEntry, action: 'read' | 'delete') {
  if (action === 'read') markEntriesRead(entry.ids);
  else remove(entry.ids);
}

/** Back to the list, with what was done for a moment (iOS NotificationResolvedBar). */
function handleResolved(outcome: ReviewOutcome) {
  select(null);
  clearTimeout(resolvedTimer);
  resolved.value = outcome === 'verified' ? NOTIFICATIONS_RESOLVED_VERIFIED : NOTIFICATIONS_RESOLVED_REJECTED;
  resolvedTimer = setTimeout(() => (resolved.value = null), RESOLVED_MS);
}

function editFromDetails(itemId: string) {
  openedItemId.value = null;
  editedItemId.value = itemId;
}

// Opening a notification marks it as read, also when it is opened through a link or the banner.
watch(selected, (notification) => {
  // An e-mail conversation is marked read by the conversation itself.
  if (!notification?.isUnread || notification.kind === 'email') return;
  notifications.markRead(idsOf(notification, inbox.value));
});

// The banner is for elsewhere: here the list shows what arrived.
watch(
  () => state.value.banner,
  (banner) => {
    if (banner) notifications.dismissBanner();
  },
  { immediate: true },
);

onMounted(() => {
  notifications.load();
  vault.load();
  email.load();
});

onBeforeUnmount(() => {
  clearTimeout(undoTimer);
  clearTimeout(resolvedTimer);
});
</script>

<template>
  <main class="flex min-h-0 flex-1 flex-col bg-surface">
    <header class="flex shrink-0 items-center gap-2 px-4 pt-7.5 sm:px-13.25">
      <LayoutMenuLogo />
      <AylaSlashIcon class="h-7.5 w-4.5" />
      <h1 class="text-3xl font-semibold text-brand">{{ NOTIFICATIONS_TITLE }}</h1>
    </header>

    <div class="mx-auto flex min-h-0 w-full max-w-300 flex-1 flex-col gap-4 px-4 pb-6 pt-6 sm:px-13.25">
      <NotificationAlertsCard />
      <EmailCard v-if="email.state.value.isAvailable && email.state.value.status === 'ready' && !email.hasAccount.value" @connect="isEmailOpen = true" />

      <NotificationToolbar
        v-model:tab="tab"
        v-model:search-text="searchText"
        :unread-count="unreadCount"
        :trash-count="trash.length"
        :has-email="email.hasAccount.value"
        :shows-email="email.state.value.isAvailable"
        @mark-all-read="markAllRead"
        @open-trash="isTrashOpen = true"
        @compose="isComposeOpen = true"
        @open-email="isEmailOpen = true"
      />

      <p v-if="!problem && email.state.value.problem && email.hasAccount.value" role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">
        {{ email.state.value.problem }}
      </p>
      <p v-if="problem" role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">{{ problem }}</p>
      <p
        v-else-if="state.loadError && state.status === 'ready'"
        role="alert"
        class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected"
      >
        {{ state.loadError }}
      </p>

      <div class="flex min-h-0 flex-1 overflow-hidden rounded-2xl border border-card-line bg-white">
        <div :class="selected ? 'max-lg:hidden' : ''" class="flex w-full min-w-0 flex-col overflow-y-auto border-card-line p-2 lg:w-96 lg:shrink-0 lg:border-r">
          <p v-if="state.status === 'idle' || state.status === 'loading'" role="status" class="p-4 text-sm text-subtle">{{ NOTIFICATIONS_LOADING }}</p>
          <div v-else-if="state.status === 'failed'" role="alert" class="p-4 text-sm text-danger">
            {{ state.loadError }}
            <button type="button" class="ml-1 font-semibold underline" @click="notifications.load()">{{ NOTIFICATIONS_RETRY }}</button>
          </div>
          <template v-else>
            <NotificationFairSection v-show="showsFair" class="px-1 pb-2 pt-2" />
            <!-- The invitations above are what there is: no "nothing here" under them. -->
            <LayoutEmptyState
              v-if="!visible.length && !(showsFair && tab === 'applications')"
              :icon="isFiltered ? 'search' : 'mailOpen'"
              :title="isFiltered ? NOTIFICATIONS_NONE_FOUND_TITLE : emptyText.title"
              :message="isFiltered ? NOTIFICATIONS_NONE_FOUND_MESSAGE : emptyText.message"
              class="py-16"
            />
            <NotificationList v-else-if="visible.length" :sections="sections" :selected-id="selectedId" class="py-2" @open="open" @action="handleAction" />
          </template>
        </div>

        <div :class="selected ? '' : 'max-lg:hidden'" class="min-w-0 flex-1 overflow-y-auto">
          <EmailThreadPane
            v-if="selected?.kind === 'email' && selected.emailThreadId"
            :key="selected.id"
            :thread-id="selected.emailThreadId"
            @back="select(null)"
            @delete="remove([selected.id])"
          />
          <NotificationDetail
            v-else-if="selected"
            :key="selected.id"
            :notification="selected"
            :on-resolved="handleResolved"
            @back="select(null)"
            @delete="remove(idsOf(selected, inbox))"
            @open-item="openedItemId = $event"
          />
          <LayoutEmptyState v-else icon="mailOpen" :title="NOTIFICATIONS_PICK_TITLE" :message="NOTIFICATIONS_PICK_MESSAGE" class="h-full justify-center" />
        </div>
      </div>
    </div>

    <AylaUndoToast v-if="undoIds.length" :message="undoIds.every(isEmailEntryId) ? EMAIL_DELETED : NOTIFICATIONS_DELETED" @undo="undo" />
    <div
      v-else-if="resolved"
      role="status"
      class="fixed inset-x-4 bottom-4 z-50 mx-auto flex min-h-13 max-w-md items-center gap-2.5 rounded-2xl border border-card-line bg-white px-4 py-3 shadow-lg"
    >
      <VaultIcon src="/images/vault/status-verified.svg" class="size-4.5 shrink-0 text-brand" />
      <span class="text-sm font-medium text-heading">{{ resolved }}</span>
    </div>
    <NotificationTrashDialog v-model:open="isTrashOpen" :notifications="trash" @restore="restore([$event])" />
    <VaultItemDialog :item-id="openedItemId" @close="openedItemId = null" @edit="editFromDetails" />
    <EmailAccountDialog v-model:open="isEmailOpen" />
    <EmailComposeDialog v-model:open="isComposeOpen" @sent="(threadId) => threadId && select(`${EMAIL_ENTRY_PREFIX}${threadId}`)" />
    <VaultItemEditDialog :item-id="editedItemId" @close="editedItemId = null" />
  </main>
</template>
