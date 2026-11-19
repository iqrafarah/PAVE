<script setup lang="ts">
definePageMeta({ showsChats: true });

const route = useRoute();
const projects = useAylaProjects();
const chats = useAylaChats();
const lock = useAylaChatLock();
const conversation = useAylaConversation();

const projectId = computed(() => String(route.params.id));
const project = computed(() => projects.find(projectId.value));
const projectChats = computed(() =>
  chats.state.value.conversations
    .filter(
      (chat) =>
        projects.state.value.chatProjects[chat.id] === projectId.value &&
        !lock.isLocked(chat.id) &&
        !chats.state.value.hiddenIds.includes(chat.id),
    )
    .sort((first, second) => second.updatedAt.localeCompare(first.updatedAt)),
);

const isEditing = ref(false);
const editError = ref<string | null>(null);

async function saveSettings(name: string, instructions: string, icon: string | null, color: string | null) {
  editError.value = null;
  const { isFailed } = await projects.update(projectId.value, { name, instructions, ...(projects.state.value.canStyle ? { icon, color } : {}) });
  if (isFailed) editError.value = AYLA_PROJECT_FAILED;
  else isEditing.value = false;
}

useHead({ title: computed(() => `${project.value?.name ?? AYLA_PROJECTS} - PAVE`) });

onMounted(async () => {
  conversation.startNew();
  if (projects.state.value.status !== 'ready') await projects.load();
  await projects.loadMembership();
  // A project that is gone (deleted, or not yours): back to the start screen.
  if (projects.state.value.status === 'ready' && !project.value) await navigateTo('/');
});
</script>

<template>
  <AylaChatListPage
    v-if="project"
    :key="project.id"
    :title="project.name"
    icon="folder"
    :look="projectLook(project)"
    :placeholder="getProjectChipLabel(project.name)"
    :project-id="project.id"
    :chats="projectChats"
    :empty-text="AYLA_PROJECT_EMPTY"
  >
    <template #actions>
      <button
        type="button"
        class="flex size-10 shrink-0 items-center justify-center rounded-pill text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
        :title="AYLA_PROJECT_SETTINGS"
        @click="editError = null; isEditing = true"
      >
        <LayoutPaveIcon name="settings" class="size-5" />
        <span class="sr-only">{{ AYLA_PROJECT_SETTINGS }}</span>
      </button>
    </template>
    <template #notice>
      <AylaProjectEditor
        v-if="isEditing"
        :title="AYLA_PROJECT_SETTINGS"
        :confirm-label="AYLA_SAVE"
        :initial-name="project.name"
        :initial-instructions="project.instructions"
        :initial-icon="project.icon"
        :initial-color="project.color"
        :can-style="projects.state.value.canStyle"
        :error="editError"
        @save="saveSettings"
        @close="isEditing = false"
      />
    </template>
  </AylaChatListPage>
</template>
