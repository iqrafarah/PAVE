<script setup lang="ts">
import type { NotificationKind } from '~/types/notifications';

// The coloured tile in front of a notification: green for a confirmation, red for a rejection, amber for a request.
const props = withDefaults(
  defineProps<{
    kind: NotificationKind;
    size?: 'small' | 'large';
  }>(),
  { size: 'small' },
);

const ICONS: Record<NotificationKind, string> = {
  conversation: '/images/vault/icons/ChatBubbleLeftEllipsisSolid.svg',
  evidence_verified: '/images/vault/status-verified.svg',
  evidence_rejected: '/images/vault/status-rejected.svg',
  verification_request: '/images/vault/icons/CheckBadgeSolid.svg',
  email: '/images/notifications/envelope.svg',
};
const TILES: Record<NotificationKind, string> = {
  conversation: 'bg-tint text-brand',
  evidence_verified: 'bg-status-verified-surface text-brand',
  evidence_rejected: 'bg-status-rejected-surface text-status-rejected',
  verification_request: 'bg-status-pending-surface text-status-pending',
  email: 'bg-tint text-brand',
};

const sizes = computed(() =>
  props.size === 'large' ? { tile: 'size-12 rounded-2xl', icon: 'size-6' } : { tile: 'size-9 rounded-xl', icon: 'size-4.5' },
);
</script>

<template>
  <span :class="[TILES[kind], sizes.tile]" class="flex shrink-0 items-center justify-center" aria-hidden="true">
    <VaultIcon :src="ICONS[kind]" :class="sizes.icon" />
  </span>
</template>
