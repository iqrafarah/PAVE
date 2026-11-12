<script setup lang="ts">
import type { MemoryCategory, MemoryNote } from '~/types/ayla';

// "Wat Ayla over je weet", one to one with the iPhone (ios/PAVE/Features/Ayla/Memory): the switch, a folder per
// category and "Alles vergeten". ?map=<category> opens a folder (AylaMemoryFolderScreen) with its notes.
interface EditorState {
  title: string;
  note: MemoryNote | null;
  category: MemoryCategory;
}

const route = useRoute();
const memory = useAylaMemory();

const editor = ref<EditorState | null>(null);
const hiddenIds = ref<string[]>([]);
const problem = ref<string | null>(null);
const confirmRef = useTemplateRef<{ open: () => void }>('confirm');

const undoForget = useUndoDelay({
  onCommit: commitForget,
  onUndo: (id) => unhide(id),
});

const status = computed(() => memory.state.value.status);
const isEnabled = computed(() => memory.state.value.isEnabled);
const notes = computed(() => memory.state.value.notes.filter((note) => !hiddenIds.value.includes(note.id)));
const openFolder = computed(() => MEMORY_CATEGORIES.find((category) => category.id === route.query.map) ?? null);
const folderNotes = computed(() => notes.value.filter((note) => note.category === openFolder.value?.id));
const pageTitle = computed(() => openFolder.value?.title ?? MEMORY_PAGE_TITLE);

useHead({ title: () => `${pageTitle.value} - PAVE` });

function countNotes(category: MemoryCategory) {
  return notes.value.filter((note) => note.category === category).length;
}

function unhide(id: string) {
  hiddenIds.value = hiddenIds.value.filter((hiddenId) => hiddenId !== id);
}

async function commitForget(id: string) {
  const { isFailed } = await memory.deleteNote(id);
  if (isFailed) problem.value = AYLA_MEMORY_FORGET_FAILED;
  unhide(id);
}

// Takes the note away at once; it is really forgotten after 5 seconds, unless "Ongedaan maken" brings it back.
function forget(id: string) {
  problem.value = null;
  hiddenIds.value = [...hiddenIds.value, id];
  undoForget.schedule(id);
}

function startAdding() {
  editor.value = { title: MEMORY_ADD, note: null, category: openFolder.value?.id ?? 'personal' };
}

function startEditing(note: MemoryNote) {
  editor.value = { title: MEMORY_EDIT, note, category: note.category };
}

async function save(text: string, category: MemoryCategory) {
  const note = editor.value?.note;
  problem.value = null;
  const { isFailed } = note ? await memory.updateNote(note.id, text, category) : await memory.addNote(text, category);
  if (isFailed) problem.value = AYLA_MEMORY_SAVE_FAILED;
}

async function setEnabled(event: Event) {
  problem.value = null;
  const { isFailed } = await memory.setEnabled((event.target as HTMLInputElement).checked);
  if (isFailed) problem.value = MEMORY_SETTING_FAILED;
}

async function forgetAll() {
  problem.value = null;
  const { isFailed } = await memory.forgetAll();
  if (isFailed) problem.value = AYLA_MEMORY_FORGET_FAILED;
}

// As on iOS, leaving a folder forgets the waiting note right away.
watch(openFolder, () => undoForget.commitNow());

// Only the first time: coming back from a folder must not bring back a note that is still being forgotten.
onMounted(() => {
  if (status.value !== 'ready') memory.load();
});
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col bg-surface">
    <AylaMemoryHeader
      v-if="openFolder"
      :title="openFolder.title"
      :back-label="MEMORY_PAGE_TITLE"
      :back-to="{ query: {} }"
      :add-label="getAddToFolderLabel(openFolder.title)"
      @add="startAdding"
    />
    <AylaMemoryHeader
      v-else
      :title="MEMORY_PAGE_TITLE"
      :back-label="SETTINGS_TITLE"
      back-to="/instellingen"
      :add-label="status === 'ready' ? MEMORY_ADD : undefined"
      @add="startAdding"
    />

    <AylaDataLoader v-if="status === 'loading' || status === 'idle'" :shows-cards="false" class="flex items-center" />

    <div v-else-if="status === 'notSetUp'" class="flex flex-1 items-center px-8">
      <LayoutEmptyState icon="database" :title="AYLA_NOT_AVAILABLE_YET" :message="AYLA_MEMORY_NOT_SET_UP" />
    </div>

    <div v-else-if="status === 'failed'" class="flex flex-1 items-center px-8">
      <LayoutEmptyState icon="database" :title="MEMORY_NOT_LOADED" :message="MEMORY_LOAD_FAILED">
        <button
          type="button"
          class="mt-4 min-h-11 rounded-lg px-3 text-sm font-semibold text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand"
          @click="memory.load"
        >
          {{ AYLA_RETRY }}
        </button>
      </LayoutEmptyState>
    </div>

    <div v-else class="min-h-0 flex-1 overflow-y-auto">
      <div class="mx-auto w-full max-w-160 px-5 pb-8 pt-4 @container">
        <p v-if="problem" role="alert" class="mb-4 rounded-2xl bg-white px-4 py-3 text-sm font-medium text-critical">
          {{ problem }}
        </p>

        <!-- A folder (iOS AylaMemoryFolderScreen) -->
        <template v-if="openFolder">
          <div v-if="!folderNotes.length" class="flex min-h-96 items-center px-3">
            <LayoutEmptyState
              icon="folder"
              :title="MEMORY_EMPTY_FOLDER"
              :message="getEmptyFolderMessage(openFolder.title)"
            />
          </div>
          <template v-else>
            <ul class="divide-y divide-line overflow-hidden rounded-xl bg-white">
              <AylaMemoryNoteItem
                v-for="note in folderNotes"
                :key="note.id"
                :note="note"
                :is-enabled="isEnabled"
                @edit="startEditing(note)"
                @forget="forget(note.id)"
              />
            </ul>
            <p v-if="!isEnabled" class="mt-2 px-4 text-xs/normal text-subtle">{{ MEMORY_FOLDER_OFF }}</p>
          </template>
        </template>

        <!-- All folders (iOS AylaMemoryScreen) -->
        <template v-else>
          <label class="flex cursor-pointer items-center gap-4 rounded-2xl bg-white px-4 py-3">
            <span class="flex-1 text-base font-semibold text-heading">{{ MEMORY_SWITCH_LABEL }}</span>
            <input
              type="checkbox"
              role="switch"
              :checked="isEnabled"
              aria-describedby="memory-explanation"
              class="peer sr-only"
              @change="setEnabled"
            />
            <span
              class="relative h-7.75 w-12.75 shrink-0 rounded-full bg-line transition-colors peer-checked:bg-brand peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-brand motion-reduce:transition-none"
              aria-hidden="true"
            >
              <span
                :class="isEnabled ? 'translate-x-5' : 'translate-x-0'"
                class="absolute left-0.5 top-0.5 size-6.75 rounded-full bg-white shadow transition-transform motion-reduce:transition-none"
              />
            </span>
          </label>
          <p id="memory-explanation" class="px-4 pt-2 text-xs/normal text-subtle">
            {{ isEnabled ? MEMORY_ON_EXPLANATION : MEMORY_OFF_NOTICE }}
          </p>

          <p v-if="!notes.length" class="px-4 pt-6 text-sm font-medium text-subtle">{{ MEMORY_NOTHING_YET }}</p>

          <ul class="grid grid-cols-2 gap-2.5 pt-6 @lg:grid-cols-3">
            <li v-for="category in MEMORY_CATEGORIES" :key="category.id">
              <AylaMemoryFolder :category="category.id" :title="category.title" :count="countNotes(category.id)" />
            </li>
          </ul>

          <button
            v-if="notes.length"
            type="button"
            class="mt-6 min-h-12.5 w-full rounded-2xl bg-white text-base font-semibold text-critical hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-critical"
            @click="confirmRef?.open()"
          >
            {{ MEMORY_FORGET_ALL }}
          </button>
        </template>
      </div>
    </div>

    <AylaMemoryEditor
      v-if="editor"
      :key="editor.note?.id ?? 'new'"
      :title="editor.title"
      :initial-text="editor.note?.text ?? ''"
      :initial-category="editor.category"
      @save="save"
      @close="editor = null"
    />

    <LayoutConfirmSheet
      ref="confirm"
      :title="MEMORY_FORGET_ALL_QUESTION"
      :message="MEMORY_FORGET_ALL_BODY"
      :confirm-label="MEMORY_FORGET_ALL"
      @confirm="forgetAll"
    />

    <AylaUndoToast v-if="undoForget.pendingId.value" :message="MEMORY_FORGET" @undo="undoForget.undo" />
  </div>
</template>
