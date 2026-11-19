<script setup lang="ts">
import type { Conversation } from '~/types/ayla';

// The panel next to a chat's ⋯ menu for "Naar project verplaatsen": a field to search or make a project, "Nieuw
// project", the projects, and "Geen project" when the chat is in one now.
const props = defineProps<{ conversation: Conversation }>();
const emit = defineEmits<{ done: [] }>();

const projects = useAylaProjects();
const query = ref('');
const isBusy = ref(false);
const inputRef = useTemplateRef<HTMLInputElement>('input');

const currentProjectId = computed(() => projects.state.value.chatProjects[props.conversation.id] ?? null);
const trimmedQuery = computed(() => query.value.trim());
const shown = computed(() => {
  const words = trimmedQuery.value.toLocaleLowerCase('nl');
  return projects.state.value.projects.filter((project) => project.name.toLocaleLowerCase('nl').includes(words));
});
const hasExactMatch = computed(() =>
  projects.state.value.projects.some((project) => project.name.toLocaleLowerCase('nl') === trimmedQuery.value.toLocaleLowerCase('nl')),
);

const rowClass =
  'flex min-h-9 w-full items-center gap-2.5 rounded-lg px-3 py-1.5 text-left text-sm text-ink hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60';

async function moveTo(projectId: string | null) {
  isBusy.value = true;
  const { isFailed } = await projects.moveChat(props.conversation.id, projectId);
  isBusy.value = false;
  // The chat simply shows up under its project; only a failure is said out loud.
  if (isFailed) projects.showNotice(AYLA_PROJECT_MOVE_FAILED, true);
  emit('done');
}

// "Nieuw project": makes the project with the typed name and puts the chat in it. Without a name the field gets the focus.
async function createAndMove() {
  if (!trimmedQuery.value) {
    inputRef.value?.focus();
    return;
  }
  isBusy.value = true;
  const { project, isFailed } = await projects.create(trimmedQuery.value);
  isBusy.value = false;
  if (isFailed || !project) {
    projects.showNotice(AYLA_PROJECT_FAILED, true);
    emit('done');
    return;
  }
  await moveTo(project.id);
}

onMounted(() => inputRef.value?.focus({ preventScroll: true }));
</script>

<template>
  <div>
    <label class="sr-only" for="move-project-search">{{ AYLA_MOVE_SEARCH }}</label>
    <input
      id="move-project-search"
      ref="input"
      v-model="query"
      type="text"
      autocomplete="off"
      :maxlength="AYLA_MAX_TITLE_LENGTH"
      :placeholder="AYLA_MOVE_SEARCH"
      class="w-full rounded-lg bg-transparent px-3 py-2 text-sm text-heading placeholder:text-subtle focus:outline-none"
      @keydown.enter.prevent="hasExactMatch ? null : createAndMove()"
    />
    <div class="my-1 border-t border-line" />
    <button type="button" :disabled="isBusy" :class="rowClass" @click="createAndMove">
      <LayoutIcon name="plus" class="size-4 shrink-0 text-brand" />
      <span class="min-w-0 truncate">{{ trimmedQuery && !hasExactMatch ? AYLA_MOVE_CREATE(trimmedQuery) : AYLA_NEW_PROJECT }}</span>
    </button>
    <ul class="mt-1 max-h-60 overflow-y-auto border-t border-line pt-1">
      <li v-for="project in shown" :key="project.id">
        <button type="button" :disabled="isBusy" :class="rowClass" @click="moveTo(project.id)">
          <VaultIcon :src="projectLook(project).iconSrc" :style="{ color: projectLook(project).hex ?? undefined }" class="size-4 shrink-0 text-brand" />
          <span class="min-w-0 flex-1 truncate">{{ project.name }}</span>
          <LayoutPaveIcon v-if="project.id === currentProjectId" name="check" class="size-4 shrink-0 text-brand" />
        </button>
      </li>
      <li v-if="!shown.length && trimmedQuery" class="px-3 py-2 text-xs text-subtle">{{ AYLA_MOVE_NOTHING_FOUND }}</li>
      <li v-if="currentProjectId" class="mt-1 border-t border-line pt-1">
        <button type="button" :disabled="isBusy" :class="rowClass" @click="moveTo(null)">
          <LayoutIcon name="close" class="size-4 shrink-0 text-brand" />
          {{ AYLA_REMOVE_FROM_PROJECT }}
        </button>
      </li>
    </ul>
  </div>
</template>
