<script setup lang="ts">
import type { PaveNotification } from '~/types/notifications';

// A decision on your evidence in the pane beside the inbox: what was decided, the evidence as it is now in your vault,
// the reason after a rejection and the way to ask again.
const props = defineProps<{
  notification: PaveNotification;
}>();

const emit = defineEmits<{
  openItem: [itemId: string];
}>();

const vault = useVault();
const requestItemId = ref<string | null>(null);

const item = computed(() => vault.state.value.items.find((entry) => entry.id === props.notification.vaultItemId) ?? null);
const isVerified = computed(() => props.notification.kind === 'evidence_verified');
const organisation = computed(() => props.notification.personName);
const explanation = computed(() =>
  isVerified.value ? NOTIFICATION_VERIFIED_MESSAGE(organisation.value) : NOTIFICATION_REJECTED_MESSAGE(organisation.value),
);
const reason = computed(() => (item.value ? rejectionReason(item.value) : null));
const place = computed(() => (item.value ? itemPlace(item.value) : null));
const period = computed(() => (item.value ? itemPeriod(item.value) : null));

const secondaryButton =
  'inline-flex min-h-10 items-center gap-2 rounded-field border border-field-line px-3.5 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand';
</script>

<template>
  <div class="flex flex-col gap-5 p-6">
    <p class="max-w-xl text-sm text-heading">{{ explanation }}</p>

    <p v-if="vault.state.value.status === 'ready' && !item" class="text-sm text-subtle">{{ NOTIFICATIONS_EVIDENCE_GONE }}</p>
    <template v-else-if="item">
      <div class="flex max-w-xl items-center gap-3.5 rounded-2xl border border-card-line bg-white p-4">
        <VaultLogo :name="item.organisationName ?? item.title" :logo-url="item.logoUrl" :size="52" />
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <p class="truncate font-semibold text-heading">{{ item.title }}</p>
            <VaultStatusBadge :status="item.status" :is-awaiting="isAwaitingReview(item)" />
          </div>
          <div class="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-xs font-medium text-subtle">
            <span v-if="place" class="flex items-center gap-1.5"><VaultIcon src="/images/vault/building.svg" class="size-4" />{{ place }}</span>
            <span v-if="period" class="flex items-center gap-1.5"><VaultIcon src="/images/vault/calendar.svg" class="size-4" />{{ period }}</span>
          </div>
        </div>
      </div>

      <div v-if="reason" class="max-w-xl rounded-xl bg-status-rejected-surface p-4">
        <p class="text-xs font-medium text-status-rejected">{{ rejectionReasonTitle(item.lastRequest?.organisationName) }}</p>
        <p class="mt-1 whitespace-pre-wrap text-sm text-heading">{{ reason }}</p>
      </div>

      <div class="flex flex-wrap gap-2">
        <button type="button" :class="secondaryButton" @click="emit('openItem', item.id)">
          <VaultIcon src="/images/vault/icons/FolderSolid.svg" class="size-4.5" />
          {{ NOTIFICATION_OPEN_IN_VAULT }}
        </button>
        <button
          v-if="!isVerified && canRequestConfirmation(item)"
          type="button"
          class="inline-flex min-h-10 items-center gap-2 rounded-field bg-brand px-3.5 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="requestItemId = item.id"
        >
          <VaultIcon src="/images/vault/icons/CheckBadgeSolid.svg" class="size-4.5" />
          {{ VAULT_REQUEST_AGAIN_ACTION }}
        </button>
      </div>
      <VaultRequestDialog :item-id="requestItemId" @close="requestItemId = null" />
    </template>
  </div>
</template>
