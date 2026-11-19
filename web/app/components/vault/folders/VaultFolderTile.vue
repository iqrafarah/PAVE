<script setup lang="ts">
// A folder above the vault list (Figma "Certificaten, 8 items"), compact like iOS VaultFolderTile: a band in the
// folder's light colour with the folder over its edge, the name and how many items it holds. Clicking it opens it.
withDefaults(
  defineProps<{
    title: string;
    icon: string;
    count: number;
    color?: string;
    surface?: string;
    iconColor?: string;
    isPinned?: boolean;
  }>(),
  { color: 'var(--color-brand)', surface: 'var(--color-tint)', iconColor: 'white', isPinned: false },
);

const emit = defineEmits<{
  open: [];
}>();
</script>

<template>
  <div class="group relative w-full">
    <button
      type="button"
      class="relative flex w-full flex-col overflow-hidden rounded-2xl bg-white text-left shadow-[0_1px_6px_rgb(0_0_0/0.06)] transition-shadow hover:shadow-[0_2px_10px_rgb(0_0_0/0.1)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('open')"
    >
      <span class="relative h-12.5 w-full shrink-0" :style="{ background: `color-mix(in srgb, ${surface} var(--vault-tint-strength, 100%), var(--color-panel))` }" aria-hidden="true">
        <span class="absolute bottom-[-0.4375rem] left-3.25 h-9.5 w-11.5">
          <VaultIcon src="/images/vault/folder-shape.svg" class="size-full" :style="{ color }" />
          <VaultIcon :src="icon" class="absolute left-1/2 top-1/2 size-4.5 -translate-x-1/2 -translate-y-[38%]" :style="{ color: iconColor }" />
        </span>
      </span>
      <span class="flex min-w-0 flex-col gap-0.5 px-3.25 pb-2.5 pt-3.25">
        <span class="flex min-w-0 items-center gap-1">
          <span class="truncate text-sm font-semibold text-ink">{{ title }}</span>
          <LayoutPaveIcon v-if="isPinned" name="pin" class="size-3.5 shrink-0 text-ink-soft" aria-hidden="true" />
          <span v-if="isPinned" class="sr-only">, {{ VAULT_FOLDER_PINNED }}</span>
        </span>
        <span class="text-xs font-medium text-ink-soft">{{ itemCount(count) }}</span>
      </span>
    </button>
    <!-- Shown on hover and keyboard focus; always on touch screens, which have no hover. -->
    <div
      class="absolute right-1.5 top-1.5 opacity-0 transition-opacity group-hover:opacity-100 focus-within:opacity-100 has-[[aria-expanded=true]]:opacity-100 [@media(hover:none)]:opacity-100"
    >
      <slot name="actions" />
    </div>
  </div>
</template>
