<script setup lang="ts">
import type { Conversation } from '~/types/ayla';

useHead({ title: `${AYLA_ARCHIVED_CHATS} - PAVE` });

// Archived chats live here in the settings only: search them, sort them, put one back or delete it for good.
const chats = useAylaChats();
const projects = useAylaProjects();

const search = ref('');
const sort = ref<'newest' | 'oldest' | 'name'>('newest');
const projectFilter = ref('all');
const actionError = ref<string | null>(null);
const deleteTarget = ref<Conversation | null>(null);
const deleteConfirmRef = useTemplateRef<{ open: () => void }>('deleteConfirm');

const status = computed(() => chats.state.value.status);
const projectOf = (chat: Conversation) => projects.state.value.chatProjects[chat.id] ?? null;
const projectsWithChats = computed(() =>
  projects.state.value.projects.filter((project) => chats.archivedConversations.value.some((chat) => projectOf(chat) === project.id)),
);
const hasChatsWithoutProject = computed(() => chats.archivedConversations.value.some((chat) => !projectOf(chat)));

const shown = computed(() => {
  const words = search.value.trim().toLocaleLowerCase('nl');
  const list = chats.archivedConversations.value.filter((chat) => {
    if (words && !chat.title.toLocaleLowerCase('nl').includes(words)) return false;
    if (projectFilter.value === 'all') return true;
    if (projectFilter.value === 'none') return !projectOf(chat);
    return projectOf(chat) === projectFilter.value;
  });
  if (sort.value === 'name') return [...list].sort((first, second) => first.title.localeCompare(second.title, 'nl'));
  const direction = sort.value === 'oldest' ? 1 : -1;
  return [...list].sort((first, second) => direction * first.updatedAt.localeCompare(second.updatedAt));
});

function formatDate(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? ''
    : date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short', year: 'numeric' });
}

async function restore(item: Conversation) {
  actionError.value = null;
  const { isFailed } = await chats.setArchived(item.id, false);
  if (isFailed) actionError.value = AYLA_UNARCHIVE_FAILED;
}

function askToDelete(item: Conversation) {
  actionError.value = null;
  deleteTarget.value = item;
  deleteConfirmRef.value?.open();
}

async function confirmDelete() {
  const item = deleteTarget.value;
  deleteTarget.value = null;
  if (!item) return;
  chats.hide(item.id);
  const { isFailed } = await chats.deleteHidden(item.id);
  if (isFailed) actionError.value = AYLA_DELETE_FAILED;
}

onMounted(() => {
  if (chats.state.value.status !== 'ready') chats.load();
  if (projects.state.value.status === 'idle') projects.load();
});

const selectClass =
  'min-h-11 w-full cursor-pointer appearance-none rounded-pill bg-white py-2 pl-4 pr-10 text-sm font-medium text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const rowButton =
  'min-h-10 shrink-0 rounded-pill px-4 text-sm font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
</script>

<template>
  <SettingsPage :title="AYLA_ARCHIVED_CHATS" wide>
    <p class="px-2 text-sm text-subtle">{{ AYLA_ARCHIVED_INTRO }}</p>

    <div class="flex flex-col gap-2.5 sm:flex-row">
      <LayoutSearchInput v-model="search" :placeholder="AYLA_ARCHIVED_SEARCH" :label="AYLA_ARCHIVED_SEARCH" class="min-w-0 flex-1" />
      <label class="relative sm:w-44">
        <span class="sr-only">{{ AYLA_ARCHIVED_SORT_LABEL }}</span>
        <select v-model="sort" :class="selectClass">
          <option value="newest">{{ AYLA_ARCHIVED_SORT_NEWEST }}</option>
          <option value="oldest">{{ AYLA_ARCHIVED_SORT_OLDEST }}</option>
          <option value="name">{{ AYLA_ARCHIVED_SORT_NAME }}</option>
        </select>
        <LayoutPaveIcon name="chevronDown" class="pointer-events-none absolute right-4 top-1/2 size-3 -translate-y-1/2 text-subtle" aria-hidden="true" />
      </label>
      <label v-if="projectsWithChats.length" class="relative sm:w-48">
        <span class="sr-only">{{ AYLA_ARCHIVED_PROJECT_LABEL }}</span>
        <select v-model="projectFilter" :class="selectClass">
          <option value="all">{{ AYLA_ARCHIVED_ALL_PROJECTS }}</option>
          <option v-if="hasChatsWithoutProject" value="none">{{ AYLA_ARCHIVED_NO_PROJECT }}</option>
          <option v-for="project in projectsWithChats" :key="project.id" :value="project.id">{{ project.name }}</option>
        </select>
        <LayoutPaveIcon name="chevronDown" class="pointer-events-none absolute right-4 top-1/2 size-3 -translate-y-1/2 text-subtle" aria-hidden="true" />
      </label>
    </div>

    <p v-if="actionError" role="alert" class="px-2 text-sm text-danger">{{ actionError }}</p>

    <p v-if="status === 'loading' || status === 'idle'" class="py-10 text-center text-sm text-subtle">{{ AYLA_CHATS_LOADING }}</p>
    <p v-else-if="!chats.archivedConversations.value.length" class="py-10 text-center text-sm text-subtle">{{ AYLA_ARCHIVED_EMPTY }}</p>
    <p v-else-if="!shown.length" class="py-10 text-center text-sm text-subtle">{{ AYLA_ARCHIVED_NO_MATCH }}</p>
    <SettingsGroup v-else>
      <div v-for="chat in shown" :key="chat.id" class="flex items-center gap-3 p-4">
        <NuxtLink
          :to="`/ayla/${chat.id}`"
          class="flex min-w-0 flex-1 flex-col gap-0.5 rounded-lg focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          <span class="truncate text-base font-semibold text-heading">{{ chat.title }}</span>
          <span class="text-sm text-subtle">{{ formatDate(chat.updatedAt) }}</span>
        </NuxtLink>
        <button type="button" :class="rowButton" class="bg-tint text-heading hover:bg-brand-soft" @click="restore(chat)">
          {{ AYLA_UNARCHIVE }}<span class="sr-only">: {{ chat.title }}</span>
        </button>
        <button type="button" :class="rowButton" class="bg-danger/10 text-danger hover:bg-danger/20" @click="askToDelete(chat)">
          {{ AYLA_DELETE }}<span class="sr-only">: {{ chat.title }}</span>
        </button>
      </div>
    </SettingsGroup>

    <LayoutConfirmSheet
      ref="deleteConfirm"
      :title="AYLA_DELETE_QUESTION"
      :message="deleteTarget ? getDeleteChatMessage(deleteTarget.title) : undefined"
      :confirm-label="AYLA_DELETE_CONFIRM"
      @confirm="confirmDelete"
    />
  </SettingsPage>
</template>
