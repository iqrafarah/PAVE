<script setup lang="ts">
import type { VaultFolderColor, VaultFolderIcon } from '~/types/vault';

// The icon and colour of a project: a search field, the theme colours and the folder icons, in a popover under the tile.
const icon = defineModel<VaultFolderIcon>('icon', { required: true });
const color = defineModel<VaultFolderColor | null>('color', { required: true });

const isOpen = ref(false);
const query = ref('');
const root = ref<HTMLElement | null>(null);
const searchId = useId();

const icons = computed(() => {
  const needle = query.value.trim().toLowerCase();
  const all = Object.keys(VAULT_FOLDER_ICONS) as VaultFolderIcon[];
  return needle ? all.filter((key) => VAULT_FOLDER_ICON_TITLES[key].toLowerCase().includes(needle)) : all;
});

const hex = computed(() => (color.value ? VAULT_FOLDER_COLORS[color.value] : null));

function toggle() {
  isOpen.value = !isOpen.value;
  query.value = '';
}

function onOutside(event: MouseEvent) {
  if (isOpen.value && root.value && !root.value.contains(event.target as Node)) isOpen.value = false;
}
onMounted(() => document.addEventListener('mousedown', onOutside));
onBeforeUnmount(() => document.removeEventListener('mousedown', onOutside));
</script>

<template>
  <div ref="root" class="relative" @keydown.escape.stop="isOpen = false">
    <button
      type="button"
      :aria-label="PROJECT_ICON_PICKER_LABEL"
      :aria-expanded="isOpen"
      :style="hex ? { color: hex } : undefined"
      class="flex size-12 shrink-0 items-center justify-center rounded-pill bg-white text-brand hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="toggle"
    >
      <VaultIcon :src="PROJECT_ICONS[icon]" class="size-6" />
    </button>

    <div
      v-if="isOpen"
      class="absolute left-0 top-full z-20 mt-2 flex w-72 max-w-[calc(100vw-4rem)] flex-col gap-4 rounded-composer border border-line bg-white p-4 shadow-lg"
    >
      <div>
        <label :for="searchId" class="sr-only">{{ PROJECT_ICON_SEARCH_PLACEHOLDER }}</label>
        <input
          :id="searchId"
          v-model="query"
          type="search"
          autocomplete="off"
          autofocus
          :placeholder="PROJECT_ICON_SEARCH_PLACEHOLDER"
          class="h-10 w-full rounded-field border border-field-line bg-white px-3 text-sm text-heading placeholder:text-subtle/50 focus:border-brand focus:outline-none"
        />
      </div>

      <fieldset class="flex justify-between">
        <legend class="sr-only">{{ VAULT_FOLDER_COLOR }}</legend>
        <label
          v-for="option in VAULT_FOLDER_PICKER_COLORS"
          :key="option"
          class="flex size-7 cursor-pointer items-center justify-center rounded-full border-2 has-focus-visible:outline-2 has-focus-visible:outline-offset-1 has-focus-visible:outline-brand"
          :style="{ borderColor: color === option ? VAULT_FOLDER_COLORS[option] : 'transparent' }"
        >
          <input v-model="color" type="radio" name="project-color" :value="option" class="sr-only" />
          <span class="size-5 rounded-full" :style="{ background: VAULT_FOLDER_COLORS[option] }" aria-hidden="true" />
          <span class="sr-only">{{ VAULT_FOLDER_COLOR_TITLES[option] }}</span>
        </label>
      </fieldset>

      <fieldset>
        <legend class="sr-only">{{ VAULT_FOLDER_ICON }}</legend>
        <div v-if="icons.length" class="grid grid-cols-6 gap-1.5">
          <label
            v-for="option in icons"
            :key="option"
            :class="icon === option ? '' : 'text-heading hover:bg-tint'"
            :style="icon === option && hex ? { background: hex, color: 'white' } : undefined"
            class="flex size-9 cursor-pointer items-center justify-center rounded-lg has-focus-visible:outline-2 has-focus-visible:outline-brand"
            :title="VAULT_FOLDER_ICON_TITLES[option]"
          >
            <input v-model="icon" type="radio" name="project-icon" :value="option" class="sr-only" />
            <VaultIcon :src="PROJECT_ICONS[option]" class="size-5" />
            <span class="sr-only">{{ VAULT_FOLDER_ICON_TITLES[option] }}</span>
          </label>
        </div>
        <p v-else class="text-xs text-subtle">{{ PROJECT_ICON_NONE_FOUND }}</p>
      </fieldset>
    </div>
  </div>
</template>
