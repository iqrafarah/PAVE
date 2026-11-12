<script setup lang="ts">
import type { VaultItemCategory } from '~/types/vault';

// "Map": every folder the item can be in, as a dropdown like the other fields. A standard folder is the kind of item
// (Certificaten = certificate), so choosing one also changes "Soort"; one of your own folders keeps the kind.
const props = defineProps<{
  id: string;
  // A confirmed item keeps its kind (the database refuses), so it can only go into your own folders.
  canChangeCategory: boolean;
}>();

const folderId = defineModel<string | null>('folderId', { required: true });
const category = defineModel<VaultItemCategory | ''>('category', { required: true });

const vault = useVault();
// Opened from a chat, the vault may not have been read yet; the folders come with it.
onMounted(() => {
  if (vault.state.value.status !== 'ready') vault.load();
});

const standardFolders = computed(() =>
  VAULT_CATEGORIES.filter((option) => !vault.state.value.categoryFolders[option]?.isHidden || option === category.value).map(
    (option) => {
      const entry = vault.shelves.value.find((shelf) => shelf.shelf.kind === 'category' && shelf.shelf.category === option);
      return { category: option, title: entry?.title ?? VAULT_CATEGORY_PLURALS[option], twinId: entry?.shelf.kind === 'category' ? entry.shelf.folderId : undefined };
    },
  ),
);
const ownFolders = computed(() => vault.shelves.value.filter((entry) => !entry.isStandard));

const value = computed({
  get() {
    const twin = standardFolders.value.find((entry) => entry.twinId && entry.twinId === folderId.value);
    if (folderId.value && !twin) return `folder:${folderId.value}`;
    if (twin) return `category:${twin.category}`;
    return category.value ? `category:${category.value}` : '';
  },
  set(next: string) {
    const [kind, key] = next.split(':') as ['folder' | 'category', string];
    if (kind === 'folder') {
      folderId.value = key;
      return;
    }
    folderId.value = null;
    category.value = key as VaultItemCategory;
  },
});

const fieldClass =
  'h-9.75 w-full min-w-0 rounded-field border border-field-line bg-white px-3 text-sm font-medium text-heading focus:border-brand focus:outline-none';
</script>

<template>
  <select :id="props.id" v-model="value" :class="[fieldClass, value ? '' : 'text-subtle/60']">
    <option value="" disabled>{{ VAULT_FIELD_FOLDER_PLACEHOLDER }}</option>
    <optgroup :label="VAULT_MOVE_STANDARD">
      <option
        v-for="entry in standardFolders"
        :key="entry.category"
        :value="`category:${entry.category}`"
        :disabled="!canChangeCategory && entry.category !== category"
        class="text-heading"
      >
        {{ entry.title }}
      </option>
    </optgroup>
    <optgroup v-if="ownFolders.length" :label="VAULT_MOVE_OWN">
      <option v-for="entry in ownFolders" :key="entry.key" :value="`folder:${entry.shelf.kind === 'folder' ? entry.shelf.id : ''}`" class="text-heading">
        {{ entry.title }}
      </option>
    </optgroup>
  </select>
</template>
