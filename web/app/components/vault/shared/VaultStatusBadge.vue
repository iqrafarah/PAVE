<script setup lang="ts">
import type { VaultStatus } from '~/types/vault';

// Whether an item is confirmed, with the colours from the design (Figma "Geverifieerd", "Afgewezen"). While a request is
// open it says "In afwachting" with a clock (iOS VaultStatusBadge).
const props = defineProps<{
  status: VaultStatus;
  isAwaiting?: boolean;
}>();

const style = computed(() => VAULT_STATUS_STYLES[props.isAwaiting ? 'toVerify' : props.status]);
const title = computed(() => (props.isAwaiting ? REQUEST_AWAITING_TITLE : VAULT_STATUS_TITLES[props.status]));
</script>

<template>
  <span :class="style.className" class="inline-flex h-6 shrink-0 items-center gap-0.75 whitespace-nowrap rounded-md pl-0.75 pr-1.25 text-xs font-medium">
    <VaultIcon :src="style.icon" class="size-4" />
    <span class="sr-only">Status:</span>
    {{ title }}
  </span>
</template>
