<script setup lang="ts">
import type { VaultItem } from '~/types/vault';

// "Bronnen" on the start page of a project, like ChatGPT: the vault items Ayla uses in every chat of the project, with
// "Toevoegen" to upload a file (it becomes an item in your vault) or to take items out of your vault.
const props = defineProps<{
  projectId: string;
  sort: 'newest' | 'oldest' | 'name';
  // 'all' or a vault category.
  filter: string;
}>();

const sources = useAylaProjectSources();
const vault = useVault();
const vaultAdd = useVaultAdd();
const pickerRef = useTemplateRef<{ open: () => void }>('picker');
const menuId = useId();
const isMenuOpen = ref(false);
const rootRef = useTemplateRef<HTMLElement>('root');
const error = ref<string | null>(null);

const allItems = computed(() => sources.itemsOf(props.projectId));
const items = computed(() => {
  const shown = allItems.value.filter((item) => props.filter === 'all' || item.category === props.filter);
  if (props.sort === 'name') return [...shown].sort((a, b) => a.title.localeCompare(b.title, 'nl'));
  // The list from the composable is newest added first.
  return props.sort === 'oldest' ? [...shown].reverse() : shown;
});
const isLoading = computed(() => sources.state.value.status === 'loading' || sources.state.value.status === 'idle');

function formatDate(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' });
}

function onOutside(event: MouseEvent) {
  if (isMenuOpen.value && rootRef.value && !rootRef.value.contains(event.target as Node)) isMenuOpen.value = false;
}
onMounted(() => document.addEventListener('mousedown', onOutside));
onBeforeUnmount(() => document.removeEventListener('mousedown', onOutside));

/** A source is for Ayla to use, so adding one also gives the "Ayla mag dit bekijken en gebruiken" yes for that item. */
async function addItems(picked: VaultItem[]) {
  error.value = null;
  const { isFailed } = await sources.add(props.projectId, picked.map((item) => item.id));
  if (isFailed) error.value = AYLA_SOURCES_FAILED;
}

function upload() {
  isMenuOpen.value = false;
  error.value = null;
  vaultAdd.open({
    onSaved: async (itemId) => {
      try {
        await vault.setAylaAllowed(itemId, true);
      } catch {
        error.value = AYLA_SOURCES_ALLOW_FAILED;
      }
      const { isFailed } = await sources.add(props.projectId, [itemId]);
      if (isFailed) error.value = AYLA_SOURCES_FAILED;
    },
  });
}

function fromVault() {
  isMenuOpen.value = false;
  pickerRef.value?.open();
}

async function remove(item: VaultItem) {
  error.value = null;
  const { isFailed } = await sources.remove(props.projectId, item.id);
  if (isFailed) error.value = AYLA_SOURCES_FAILED;
}
</script>

<template>
  <div class="mt-5">
    <!-- Empty: a dashed box with the add button in the middle, like ChatGPT. With sources the button sits above the list. -->
    <div
      :class="allItems.length || isLoading ? '' : 'flex min-h-72 flex-col items-center justify-center rounded-composer border border-dashed border-field-line px-6 py-10 text-center'"
    >
      <template v-if="!allItems.length && !isLoading">
        <p class="font-heading text-lg font-semibold text-heading">{{ AYLA_SOURCES_EMPTY_TITLE }}</p>
        <p class="mt-2 max-w-sm text-sm text-subtle">{{ AYLA_SOURCES_EMPTY }}</p>
      </template>

      <div ref="root" class="relative flex" :class="allItems.length || isLoading ? 'justify-end px-1' : 'mt-6 justify-center'">
        <button
          type="button"
          aria-haspopup="menu"
          :aria-expanded="isMenuOpen"
          :aria-controls="menuId"
          class="inline-flex min-h-10.75 items-center gap-1.5 rounded-pill bg-brand px-5 text-sm font-semibold text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="isMenuOpen = !isMenuOpen"
        >
          {{ AYLA_SOURCES_ADD }}
        </button>
        <ul
          v-if="isMenuOpen"
          :id="menuId"
          role="menu"
          class="absolute top-full z-20 mt-1 w-52 rounded-composer border border-line bg-white p-1.5 text-left shadow-lg"
          :class="allItems.length || isLoading ? 'right-1' : 'left-1/2 -translate-x-1/2'"
          @keydown.escape="isMenuOpen = false"
        >
          <li role="none">
            <button type="button" role="menuitem" class="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-sm text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand" @click="upload">
              <VaultIcon src="/images/vault/icons/CloudArrowUpSolid.svg" class="size-4 text-brand" />
              {{ AYLA_SOURCES_UPLOAD }}
            </button>
          </li>
          <li role="none">
            <button type="button" role="menuitem" class="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-sm text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand" @click="fromVault">
              <VaultIcon src="/images/vault/icons/FolderClosedSolid.svg" class="size-4 text-brand" />
              {{ AYLA_SOURCES_FROM_VAULT }}
            </button>
          </li>
        </ul>
      </div>
    </div>

    <p v-if="error" role="alert" class="mt-2 px-4 text-xs text-danger">{{ error }}</p>
    <p v-if="isLoading" class="mt-12 text-center text-sm text-subtle">{{ AYLA_SOURCES_LOADING }}</p>
    <p v-else-if="allItems.length && !items.length" class="mt-8 text-center text-sm text-subtle">{{ AYLA_SOURCES_NO_MATCH }}</p>
    <ul v-else-if="items.length" class="mt-2">
      <li v-for="item in items" :key="item.id" class="group flex items-center gap-2 rounded-bubble px-4 py-3 transition-colors hover:bg-tint">
        <VaultIcon :src="CATEGORY_FOLDER_ICONS[item.category]" class="size-4 text-brand" />
        <span translate="no" class="min-w-0 flex-1 truncate text-sm font-medium text-heading">{{ item.title }}</span>
        <span class="shrink-0 text-xs text-subtle">{{ formatDate(item.updatedAt) }}</span>
        <button
          type="button"
          :title="AYLA_SOURCES_REMOVE"
          class="flex size-7 shrink-0 items-center justify-center rounded-lg text-subtle hover:text-heading focus-visible:outline-2 focus-visible:outline-brand md:opacity-0 md:group-hover:opacity-100 md:group-focus-within:opacity-100"
          @click="remove(item)"
        >
          <LayoutIcon name="close" class="size-4" />
          <span class="sr-only">{{ `${AYLA_SOURCES_REMOVE}: ${item.title}` }}</span>
        </button>
      </li>
    </ul>

    <AylaVaultPicker ref="picker" @pick="addItems" />
  </div>
</template>
