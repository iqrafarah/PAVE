<script setup lang="ts">
// The panel next to a chat's ⋯ menu for "Verval" (iOS AylaChatList): follow Instellingen, never, or after a number of
// days, with when the chat goes now under it. The row asks first when a choice deletes the chat sooner.
defineProps<{
  // The chat's own choice: null follows the account, 0 never expires.
  expiryDays: number | null;
  // "Verdwijnt over 3 dagen", or nothing when the chat stays.
  expiresText: string | null;
}>();

const emit = defineEmits<{ choose: [expiryDays: number | null] }>();

const rowClass =
  'flex min-h-9 w-full items-center gap-2.5 rounded-lg px-3 py-1.5 text-left text-sm text-ink hover:bg-surface focus-visible:bg-surface focus-visible:outline-2 focus-visible:outline-brand';
</script>

<template>
  <div role="menu" :aria-label="RETENTION_EXPIRY">
    <button
      v-for="choice in CHAT_EXPIRY_CHOICES"
      :key="String(choice)"
      type="button"
      role="menuitemradio"
      :aria-checked="choice === expiryDays"
      :class="rowClass"
      @click="emit('choose', choice)"
    >
      <span class="min-w-0 flex-1 truncate">{{ getChatExpiryTitle(choice) }}</span>
      <LayoutPaveIcon v-if="choice === expiryDays" name="check" class="size-4 shrink-0 text-brand" />
    </button>
    <p v-if="expiresText" class="mt-1 border-t border-line px-3 pb-1 pt-2 text-xs text-subtle">{{ expiresText }}</p>
  </div>
</template>
