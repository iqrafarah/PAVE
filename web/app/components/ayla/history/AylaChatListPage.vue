<script setup lang="ts">
import type { Conversation } from '~/types/ayla';

// The start page of a project or of Vergrendelde chats, like ChatGPT: the title, a chatbox for a new chat in it, and
// under that the chats that belong here.
const props = defineProps<{
  title: string;
  icon: 'folder' | 'lock' | 'lockOpen';
  placeholder: string;
  chats: Conversation[];
  emptyText: string;
  // The own icon and colour of a project (projectLook); without it the default folder.
  look?: { iconSrc: string; hex: string | null };
  projectId?: string;
  isLocked?: boolean;
}>();

// Projects have two tabs, like ChatGPT: Chats and Bronnen. Without the sources table there is no tab.
const sources = useAylaProjectSources();
const tab = ref<'chats' | 'sources'>('chats');
const sourceSort = ref<'newest' | 'oldest' | 'name'>('newest');
const sourceFilter = ref('all');
const sourceCategories = computed(() => [...new Set(sources.itemsOf(props.projectId ?? '').map((item) => item.category))]);
const hasTabs = computed(() => Boolean(props.projectId) && sources.state.value.status !== 'unavailable');
onMounted(() => props.projectId && sources.load(props.projectId));
function formatDate(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' });
}
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <AylaTitleBar :shows-title="false" />

    <div class="mx-auto flex min-h-0 w-full max-w-170 flex-1 flex-col px-4 pt-8">
      <div class="flex items-center gap-3.5">
        <span
          class="flex size-11 shrink-0 items-center justify-center rounded-pill bg-tint text-brand"
          :style="look?.hex ? { color: look.hex, background: `color-mix(in srgb, ${look.hex} 12%, white)` } : undefined"
        >
          <VaultIcon v-if="icon === 'folder'" :src="look?.iconSrc ?? '/images/vault/icons/FolderClosedSolid.svg'" class="size-5.5" />
          <LayoutPaveIcon v-else :name="icon" class="size-5" />
        </span>
        <h1 class="min-w-0 flex-1 truncate font-heading text-2xl font-semibold text-heading">{{ title }}</h1>
        <slot name="actions" />
      </div>

      <AylaChatView
        class="mt-2"
        has-composer-on-top
        :project-id="projectId"
        :is-locked="isLocked"
        :placeholder="placeholder"
      >
        <template #empty>
          <div class="min-h-0 flex-1 overflow-y-auto pb-8">
            <slot name="notice" />
            <div v-if="hasTabs" class="mt-4 flex items-center gap-1">
              <div role="tablist" class="flex flex-1 gap-1">
              <button
                v-for="option in ([['chats', AYLA_PROJECT_TAB_CHATS], ['sources', AYLA_PROJECT_SOURCES]] as const)"
                :key="option[0]"
                type="button"
                role="tab"
                :aria-selected="tab === option[0]"
                :class="tab === option[0] ? 'bg-tint text-heading' : 'text-subtle hover:text-heading'"
                class="rounded-pill px-5 py-2.5 text-sm font-medium focus-visible:outline-2 focus-visible:outline-brand"
                @click="tab = option[0]"
              >
                {{ option[1] }}
              </button>
              </div>
              <!-- Sort and filter of the sources, as in ChatGPT. -->
              <template v-if="tab === 'sources'">
                <label class="relative">
                  <span class="sr-only">{{ AYLA_SOURCES_SORT_LABEL }}</span>
                  <select v-model="sourceSort" class="cursor-pointer appearance-none rounded-pill bg-transparent py-2 pl-3 pr-8 text-sm text-subtle hover:text-heading focus-visible:outline-2 focus-visible:outline-brand">
                    <option value="newest">{{ AYLA_SOURCES_SORT_NEWEST }}</option>
                    <option value="oldest">{{ AYLA_SOURCES_SORT_OLDEST }}</option>
                    <option value="name">{{ AYLA_SOURCES_SORT_NAME }}</option>
                  </select>
                  <LayoutPaveIcon name="chevronDown" class="pointer-events-none absolute right-3 top-1/2 size-3 -translate-y-1/2 text-subtle" />
                </label>
                <label class="relative">
                  <span class="sr-only">{{ AYLA_SOURCES_FILTER_LABEL }}</span>
                  <select v-model="sourceFilter" class="cursor-pointer appearance-none rounded-pill bg-transparent py-2 pl-3 pr-8 text-sm text-subtle hover:text-heading focus-visible:outline-2 focus-visible:outline-brand">
                    <option value="all">{{ AYLA_SOURCES_FILTER_ALL }}</option>
                    <option v-for="category in sourceCategories" :key="category" :value="category">{{ VAULT_CATEGORY_PLURALS[category] }}</option>
                  </select>
                  <LayoutPaveIcon name="chevronDown" class="pointer-events-none absolute right-3 top-1/2 size-3 -translate-y-1/2 text-subtle" />
                </label>
              </template>
            </div>
            <AylaProjectSources v-if="hasTabs && projectId && tab === 'sources'" :project-id="projectId" :sort="sourceSort" :filter="sourceFilter" />
            <p v-else-if="!chats.length" class="mt-16 text-center text-sm text-subtle">{{ emptyText }}</p>
            <ul v-else class="mt-5">
              <li v-for="chat in chats" :key="chat.id">
                <NuxtLink
                  :to="`/ayla/${chat.id}`"
                  class="flex items-baseline gap-4 rounded-bubble px-4 py-3 transition-colors hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
                >
                  <span translate="no" class="min-w-0 flex-1 truncate text-sm font-medium text-heading">{{ chat.title }}</span>
                  <span class="shrink-0 text-xs text-subtle">{{ formatDate(chat.updatedAt) }}</span>
                </NuxtLink>
              </li>
            </ul>
          </div>
        </template>
      </AylaChatView>
    </div>
  </div>
</template>
