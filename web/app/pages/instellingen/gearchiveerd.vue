<script setup lang="ts">
import type { Conversation } from '~/types/ayla';
import type { VaultItem } from '~/types/vault';

// Instellingen › Archief (iOS ArchiveScreen): the chats and the evidence you archived. They are out of sight but kept;
// search and sort them, open one, put it back or delete it for good.
useHead({ title: `${RETENTION_ARCHIVE_TITLE} - PAVE` });

type Kind = 'chats' | 'evidence';
type Sort = 'newest' | 'oldest' | 'name';

const chats = useAylaChats();
const vault = useVault();

const kind = ref<Kind>('chats');
const search = ref('');
const sort = ref<Sort>('newest');
const actionError = ref<string | null>(null);
const chatToDelete = ref<Conversation | null>(null);
const itemToDelete = ref<VaultItem | null>(null);
const openedItemId = ref<string | null>(null);
const deleteChatRef = useTemplateRef<{ open: () => void }>('deleteChat');
const deleteItemRef = useTemplateRef<{ open: () => void }>('deleteItem');
const kindLabelId = useId();

const needle = computed(() =>
  search.value.trim().toLocaleLowerCase('nl').normalize('NFD').replace(/\p{Diacritic}/gu, ''),
);
function matches(text: string) {
  return !needle.value || text.toLocaleLowerCase('nl').normalize('NFD').replace(/\p{Diacritic}/gu, '').includes(needle.value);
}

function sorted<T>(list: T[], title: (entry: T) => string, date: (entry: T) => string) {
  if (sort.value === 'name') return [...list].sort((first, second) => title(first).localeCompare(title(second), 'nl', { numeric: true }));
  const direction = sort.value === 'oldest' ? 1 : -1;
  return [...list].sort((first, second) => direction * date(first).localeCompare(date(second)));
}

const archivedChats = computed(() =>
  sorted(
    chats.archivedConversations.value.filter((chat) => matches(chat.title)),
    (chat) => chat.title,
    (chat) => chat.updatedAt,
  ),
);
const archivedItems = computed(() =>
  sorted(
    vault.state.value.archived.filter((item) => matches(`${item.title} ${item.organisationName ?? ''}`)),
    (item) => item.title,
    (item) => item.archivedAt ?? item.updatedAt,
  ),
);

const isLoading = computed(() =>
  kind.value === 'chats'
    ? chats.state.value.status === 'loading' || chats.state.value.status === 'idle'
    : vault.state.value.status === 'loading',
);

function formatDate(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short', year: 'numeric' });
}

async function restoreChat(chat: Conversation) {
  actionError.value = null;
  const { isFailed } = await chats.setArchived(chat.id, false);
  if (isFailed) actionError.value = AYLA_UNARCHIVE_FAILED;
}

async function restoreItem(item: VaultItem) {
  actionError.value = null;
  if (!(await vault.setArchived(item, false))) actionError.value = vault.state.value.problem ?? ARCHIVE_FAILED;
}

function askToDeleteChat(chat: Conversation) {
  actionError.value = null;
  chatToDelete.value = chat;
  deleteChatRef.value?.open();
}

function askToDeleteItem(item: VaultItem) {
  actionError.value = null;
  itemToDelete.value = item;
  deleteItemRef.value?.open();
}

async function confirmDeleteChat() {
  const chat = chatToDelete.value;
  chatToDelete.value = null;
  if (!chat) return;
  chats.hide(chat.id);
  const { isFailed } = await chats.deleteHidden(chat.id);
  if (isFailed) actionError.value = AYLA_DELETE_FAILED;
}

async function confirmDeleteItem() {
  const item = itemToDelete.value;
  itemToDelete.value = null;
  if (item && !(await vault.remove(item))) actionError.value = vault.state.value.problem ?? ARCHIVE_FAILED;
}

watch(kind, () => (actionError.value = null));

onMounted(() => {
  chats.load();
  if (vault.state.value.status !== 'ready') vault.load();
});

const tabClass =
  'min-h-9 flex-1 rounded-pill px-4 text-sm font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const rowButton =
  'min-h-10 shrink-0 rounded-pill px-4 text-sm font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
</script>

<template>
  <SettingsPage :title="RETENTION_ARCHIVE_TITLE">
    <div role="radiogroup" :aria-labelledby="kindLabelId" class="flex gap-1 rounded-pill bg-white p-1">
      <span :id="kindLabelId" class="sr-only">{{ ARCHIVE_KIND_LABEL }}</span>
      <button
        v-for="option in (['chats', 'evidence'] as const)"
        :key="option"
        type="button"
        role="radio"
        :aria-checked="kind === option"
        :class="[tabClass, kind === option ? 'bg-brand text-white' : 'text-heading hover:bg-tint']"
        @click="kind = option"
      >
        {{ option === 'chats' ? ARCHIVE_KIND_CHATS : ARCHIVE_KIND_EVIDENCE }}
      </button>
    </div>
    <p class="px-2 text-xs/normal text-subtle">{{ RETENTION_ARCHIVE_HINT }}</p>

    <div class="flex gap-2.5">
      <LayoutSearchInput
        v-model="search"
        :placeholder="kind === 'chats' ? ARCHIVE_SEARCH_CHATS : ARCHIVE_SEARCH_EVIDENCE"
        :label="kind === 'chats' ? ARCHIVE_SEARCH_CHATS : ARCHIVE_SEARCH_EVIDENCE"
        class="min-w-0 flex-1"
      />
      <label class="relative shrink-0">
        <span class="sr-only">{{ ARCHIVE_SORT_LABEL }}</span>
        <select
          v-model="sort"
          class="min-h-11 cursor-pointer appearance-none rounded-pill bg-white py-2 pl-4 pr-10 text-sm font-medium text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          <option value="newest">{{ ARCHIVE_SORT_NEWEST }}</option>
          <option value="oldest">{{ ARCHIVE_SORT_OLDEST }}</option>
          <option value="name">{{ ARCHIVE_SORT_NAME }}</option>
        </select>
        <LayoutPaveIcon name="chevronDown" class="pointer-events-none absolute right-4 top-1/2 size-3 -translate-y-1/2 text-subtle" aria-hidden="true" />
      </label>
    </div>

    <p v-if="actionError" role="alert" class="px-2 text-sm text-danger">{{ actionError }}</p>

    <p v-if="isLoading" class="py-8 text-center text-sm text-subtle">{{ RETENTION_LOADING }}</p>

    <template v-else-if="kind === 'chats'">
      <div v-if="!chats.archivedConversations.value.length" class="flex flex-col items-center gap-2 py-8 text-center">
        <VaultIcon src="/images/settings/archive.svg" class="size-8 text-brand" />
        <p class="text-base font-semibold text-heading">{{ ARCHIVE_CHATS_EMPTY_TITLE }}</p>
        <p class="max-w-80 text-sm text-subtle">{{ ARCHIVE_CHATS_EMPTY_BODY }}</p>
      </div>
      <p v-else-if="!archivedChats.length" class="py-8 text-center text-sm text-subtle">{{ ARCHIVE_CHATS_NO_MATCH }}</p>
      <SettingsGroup v-else>
        <div v-for="chat in archivedChats" :key="chat.id" class="flex flex-wrap items-center gap-x-3 gap-y-2 px-3.5 py-2.5">
          <NuxtLink
            :to="`/ayla/${chat.id}`"
            class="flex min-h-11 min-w-0 flex-1 basis-48 items-center gap-3.5 rounded-lg focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          >
            <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-brand text-white">
              <VaultIcon src="/images/vault/icons/ChatBubbleLeftEllipsisSolid.svg" class="size-4.25" />
            </span>
            <span class="flex min-w-0 flex-col gap-0.5">
              <span class="truncate text-base font-semibold text-heading">{{ chat.title }}</span>
              <span class="text-xs text-subtle">{{ formatDate(chat.updatedAt) }}</span>
            </span>
          </NuxtLink>
          <span class="flex shrink-0 gap-2 max-sm:pl-11.5">
            <button type="button" :class="rowButton" class="bg-tint text-heading hover:bg-brand-soft" @click="restoreChat(chat)">
              {{ RETENTION_RESTORE }}<span class="sr-only">: {{ chat.title }}</span>
            </button>
            <button type="button" :class="rowButton" class="bg-danger/10 text-danger hover:bg-danger/20" @click="askToDeleteChat(chat)">
              {{ ARCHIVE_DELETE }}<span class="sr-only">: {{ chat.title }}</span>
            </button>
          </span>
        </div>
      </SettingsGroup>
    </template>

    <template v-else>
      <div v-if="!vault.state.value.archived.length" class="flex flex-col items-center gap-2 py-8 text-center">
        <VaultIcon src="/images/settings/archive.svg" class="size-8 text-brand" />
        <p class="text-base font-semibold text-heading">{{ ARCHIVE_EVIDENCE_EMPTY_TITLE }}</p>
        <p class="max-w-80 text-sm text-subtle">{{ ARCHIVE_EVIDENCE_EMPTY_BODY }}</p>
      </div>
      <p v-else-if="!archivedItems.length" class="py-8 text-center text-sm text-subtle">{{ ARCHIVE_EVIDENCE_NO_MATCH }}</p>
      <SettingsGroup v-else>
        <div v-for="item in archivedItems" :key="item.id" class="flex flex-wrap items-center gap-x-3 gap-y-2 px-3.5 py-2.5">
          <button
            type="button"
            class="flex min-h-11 min-w-0 flex-1 basis-48 items-center gap-3.5 rounded-lg text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            @click="openedItemId = item.id"
          >
            <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-brand text-white">
              <VaultIcon src="/images/vault/icons/FolderSolid.svg" class="size-4.25" />
            </span>
            <span class="flex min-w-0 flex-col gap-0.5">
              <span class="truncate text-base font-semibold text-heading">{{ item.title }}</span>
              <span class="text-xs text-subtle">{{ formatDate(item.archivedAt ?? item.updatedAt) }}</span>
            </span>
          </button>
          <span class="flex shrink-0 gap-2 max-sm:pl-11.5">
            <button type="button" :class="rowButton" class="bg-tint text-heading hover:bg-brand-soft" @click="restoreItem(item)">
              {{ RETENTION_RESTORE }}<span class="sr-only">: {{ item.title }}</span>
            </button>
            <button type="button" :class="rowButton" class="bg-danger/10 text-danger hover:bg-danger/20" @click="askToDeleteItem(item)">
              {{ ARCHIVE_DELETE }}<span class="sr-only">: {{ item.title }}</span>
            </button>
          </span>
        </div>
      </SettingsGroup>
    </template>

    <VaultItemDialog :item-id="openedItemId" @close="openedItemId = null" @edit="openedItemId = null" @request-confirmation="openedItemId = null" />

    <LayoutConfirmSheet
      ref="deleteChat"
      :title="ARCHIVE_DELETE_CHAT_TITLE"
      :message="chatToDelete ? getDeleteChatMessage(chatToDelete.title) : undefined"
      :confirm-label="ARCHIVE_DELETE"
      @confirm="confirmDeleteChat"
    />
    <LayoutConfirmSheet
      ref="deleteItem"
      :title="ARCHIVE_DELETE_ITEM_TITLE"
      :message="VAULT_DELETE_MESSAGE"
      :confirm-label="ARCHIVE_DELETE"
      @confirm="confirmDeleteItem"
    />
  </SettingsPage>
</template>
