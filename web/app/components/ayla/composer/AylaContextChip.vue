<script setup lang="ts">
// "Over: Eindstage" above the chatbox while the chat is about one vault item (iOS AylaMessages.about). ✕ stops that.
defineProps<{
  title: string;
  // Another text than "Over: …", and the folder instead of the vault icon, for a chat in a project.
  label?: string;
  icon?: 'folder' | 'lock';
  // The own icon and colour of a project (projectLook); without it the default folder.
  look?: { iconSrc: string; hex: string | null };
}>();

const emit = defineEmits<{
  clear: [];
}>();
</script>

<template>
  <div class="flex w-full max-w-147.75 justify-start px-3">
    <span class="inline-flex max-w-full items-center gap-1.5 rounded-pill bg-tint py-1 pl-3 pr-1 text-xs font-semibold text-heading">
      <VaultIcon v-if="icon === 'folder'" :src="look?.iconSrc ?? '/images/vault/icons/FolderClosedSolid.svg'" :style="{ color: look?.hex ?? undefined }" class="size-4 text-brand" />
      <LayoutPaveIcon v-else-if="icon === 'lock'" name="lock" class="size-4 text-brand" />
      <VaultIcon v-else src="/images/ayla/pill-vault.svg" :width="15" :height="13.3" class="text-brand" />
      <span class="truncate">{{ label ?? getAboutLabel(title) }}</span>
      <button
        type="button"
        :aria-label="AYLA_CLEAR_CONTEXT"
        :title="AYLA_CLEAR_CONTEXT"
        class="rounded-full p-0.5 text-subtle hover:bg-brand-soft hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('clear')"
      >
        <LayoutIcon name="close" />
      </button>
    </span>
  </div>
</template>
