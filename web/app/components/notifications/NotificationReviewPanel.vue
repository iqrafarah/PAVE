<script setup lang="ts">
import type { PaveNotification, ReviewOutcome, ReviewPayload } from '~/types/notifications';
import type { VaultItemCategory } from '~/types/vault';

// A request to confirm evidence, for the reviewer, in the pane beside the inbox: the evidence on the left, its
// documents (links that work for five minutes) on the right, and "Verifieer document" or "Aanvraag afwijzen" at the
// bottom. A rejection always needs a reason. Once decided, the list comes back with what was done (iOS).
const props = defineProps<{
  notification: PaveNotification;
  // Called once the decision is saved. A function, not an event: the saved decision removes this request from the inbox,
  // so this panel may already be gone by then.
  onResolved?: (outcome: ReviewOutcome) => void;
}>();

const { loadReview, resolve } = useNotifications();
const review = ref<ReviewPayload | null>(null);
const isLoading = ref(false);
const isWorking = ref(false);
const errorMessage = ref<string | null>(null);
const isRejectOpen = ref(false);

const item = computed(() => review.value?.item ?? null);
const documents = computed(() => item.value?.files.filter((file) => file.role === 'document') ?? []);
const logoUrl = computed(() => item.value?.files.find((file) => file.role === 'logo')?.url ?? null);
const coverUrl = computed(() => item.value?.files.find((file) => file.role === 'cover')?.url ?? null);
const category = computed(() => item.value?.category as VaultItemCategory | undefined);
const categoryTitle = computed(() => (category.value && VAULT_CATEGORY_TITLES[category.value]) || REVIEW_DEFAULT_TYPE);
const place = computed(() => (item.value ? itemPlace(item.value) : null));
const period = computed(() => (item.value ? itemPeriod(item.value) : null));
const documentName = computed(() => item.value?.title ?? props.notification.documentName ?? REJECT_FALLBACK_NAME);
const canDecide = computed(() => Boolean(review.value) && !isWorking.value);

async function load() {
  const requestId = props.notification.validationRequestId;
  if (!requestId) return;
  isLoading.value = true;
  errorMessage.value = null;
  const result = await loadReview(requestId);
  review.value = result.data;
  errorMessage.value = result.error;
  isLoading.value = false;
}

async function decide(outcome: ReviewOutcome, reason: string | null) {
  const requestId = props.notification.validationRequestId;
  if (!requestId) return REVIEW_DECISION_FAILED;
  const onResolved = props.onResolved;
  const error = await resolve(requestId, outcome, reason);
  if (!error) onResolved?.(outcome);
  return error;
}

async function verify() {
  isWorking.value = true;
  errorMessage.value = await decide('verified', null);
  isWorking.value = false;
}

function reject(reason: string) {
  return decide('rejected', reason);
}

watch(() => props.notification.id, load, { immediate: true });
</script>

<template>
  <div class="flex min-h-full flex-col" :aria-busy="isLoading">
    <div class="grid flex-1 gap-6 p-6 xl:grid-cols-[minmax(0,1fr)_16rem]">
      <div class="flex min-w-0 flex-col gap-5">
        <p v-if="isLoading" role="status" class="text-sm text-subtle">{{ NOTIFICATIONS_LOADING }}</p>
        <div v-else-if="!item" class="flex flex-col items-start gap-3">
          <p class="text-sm text-subtle">{{ errorMessage ?? REVIEW_LOAD_FAILED }}</p>
          <button type="button" class="min-h-10 rounded-field border border-field-line px-3.5 text-sm font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand" @click="load">
            {{ NOTIFICATIONS_RETRY }}
          </button>
        </div>
        <template v-else>
          <div class="overflow-hidden rounded-2xl border border-card-line bg-white">
            <div :class="category ? CATEGORY_TINTS[category] : 'bg-tint'" class="relative h-16">
              <img v-if="coverUrl" :src="coverUrl" alt="" class="size-full object-cover" />
              <VaultLogo :name="item.organisationName ?? item.title" :logo-url="logoUrl" :size="52" class="absolute left-4 top-8" />
            </div>
            <div class="flex flex-col gap-2 p-4 pt-10">
              <div class="flex flex-wrap items-start justify-between gap-2">
                <p translate="no" class="font-heading text-lg font-semibold text-heading">{{ item.title }}</p>
                <VaultStatusBadge status="toVerify" is-awaiting />
              </div>
              <p class="text-xs text-subtle">{{ categoryTitle }}</p>
              <div class="flex flex-wrap gap-x-5 gap-y-1.5 text-sm font-medium text-heading">
                <span v-if="place" class="flex items-center gap-2"><VaultIcon src="/images/vault/building.svg" class="size-4.5 text-subtle" />{{ place }}</span>
                <span v-if="period" class="flex items-center gap-2"><VaultIcon src="/images/vault/calendar.svg" class="size-4.5 text-subtle" />{{ period }}</span>
              </div>
            </div>
          </div>
          <section v-if="review?.request.message">
            <h3 class="text-xs font-medium text-subtle">{{ REVIEW_MESSAGE }}</h3>
            <p class="mt-1 whitespace-pre-wrap rounded-xl bg-surface p-3 text-sm text-heading">{{ review.request.message }}</p>
          </section>
          <section v-if="item.description">
            <h3 class="text-xs font-medium text-subtle">{{ REVIEW_DESCRIPTION }}</h3>
            <p translate="no" class="mt-1 whitespace-pre-wrap text-sm text-heading">{{ item.description }}</p>
          </section>
          <section v-if="item.skills.length">
            <h3 class="text-xs font-medium text-subtle">{{ REVIEW_SKILLS }}</h3>
            <ul class="mt-1.5 flex flex-wrap gap-1.5">
              <li v-for="skill in item.skills" :key="skill"><VaultSkillChip :text="skill" /></li>
            </ul>
          </section>
        </template>
      </div>

      <section v-if="item" class="flex flex-col gap-2">
        <h3 class="text-xs font-medium text-subtle">{{ REVIEW_DOCUMENT }}</h3>
        <ul v-if="documents.length" class="flex flex-col gap-1.5">
          <li v-for="file in documents" :key="file.id">
            <a
              :href="file.url"
              target="_blank"
              rel="noopener"
              class="flex items-center gap-2.5 rounded-xl border border-card-line bg-white p-3 text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
            >
              <VaultIcon src="/images/vault/icons/DocumentSolid.svg" class="size-5 text-brand" />
              <span translate="no" class="min-w-0 flex-1 truncate">{{ file.name }}</span>
              <LayoutIcon name="external" class="size-4 text-subtle" />
            </a>
          </li>
        </ul>
        <p v-else class="rounded-xl border border-dashed border-field-line p-4 text-center text-sm text-subtle">{{ REVIEW_NO_DOCUMENT }}</p>
      </section>
    </div>

    <div class="sticky bottom-0 flex flex-wrap items-center gap-3 border-t border-card-line bg-white px-6 py-4">
      <p class="min-w-0 flex-1 text-xs text-subtle">
        <span v-if="errorMessage && item" role="alert" class="text-danger">{{ errorMessage }}</span>
        <template v-else>{{ REVIEW_CHECK_FIRST }}</template>
      </p>
      <button
        type="button"
        :disabled="!canDecide"
        class="min-h-10 rounded-field px-3 text-sm font-medium text-danger hover:bg-status-rejected-surface focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-50"
        @click="isRejectOpen = true"
      >
        {{ REVIEW_REJECT }}
      </button>
      <button
        type="button"
        :disabled="!canDecide"
        class="min-h-10 rounded-field bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="verify"
      >
        {{ isWorking ? REVIEW_WORKING : REVIEW_VERIFY }}
      </button>
    </div>

    <NotificationRejectDialog v-model:open="isRejectOpen" :document-name="documentName" :on-reject="reject" />
  </div>
</template>
