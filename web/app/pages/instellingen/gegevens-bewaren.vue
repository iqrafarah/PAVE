<script setup lang="ts">
// Instellingen › Gegevens bewaren (iOS SettingsRetentionScreen): after how long chats disappear by themselves ("verval",
// as in WhatsApp), which chats stay anyway, and what Ayla may do with your archive. Nothing expires unless you choose it;
// deleting is final, so a choice that can delete chats at once is asked first.
useHead({ title: `${RETENTION_TITLE} - PAVE` });

const retention = useAylaChatRetention();
const problem = ref<string | null>(null);
// A choice that deletes more than before, waiting for Ja.
const pending = ref<PaveRetention | null>(null);
const confirmRef = useTemplateRef<{ open: () => void }>('confirm');
const expiryId = useId();
const startId = useId();

const status = computed(() => retention.state.value.status);
const current = computed(() => retention.state.value.retention);

async function save(chosen: PaveRetention) {
  problem.value = null;
  const { isFailed } = await retention.save(chosen);
  if (isFailed) problem.value = RETENTION_SAVE_FAILED;
}

/** One choice of the settings; it saves at once, unless it can delete chats that were kept until now. */
function change(update: (draft: PaveRetention) => void) {
  const chosen = structuredClone(toRaw(current.value));
  update(chosen);
  if (retentionDeletesMore(chosen.chatExpiry, current.value.chatExpiry)) {
    pending.value = chosen;
    confirmRef.value?.open();
  } else {
    save(chosen);
  }
}

function confirm() {
  const chosen = pending.value;
  pending.value = null;
  if (chosen) save(chosen);
}

function chooseDays(event: Event) {
  const select = event.target as HTMLSelectElement;
  const days = select.value === 'none' ? null : Number(select.value);
  change((draft) => (draft.chatExpiry.days = days));
  // Waiting for the question, the dropdown shows the saved choice until it is confirmed.
  select.value = current.value.chatExpiry.days === null ? 'none' : String(current.value.chatExpiry.days);
}

function chooseStart(event: Event) {
  const select = event.target as HTMLSelectElement;
  const start = select.value as ChatExpiryStart;
  change((draft) => (draft.chatExpiry.start = start));
  select.value = current.value.chatExpiry.start;
}

const keepsPinned = computed({
  get: () => current.value.chatExpiry.keepsPinned,
  set: (value: boolean) => change((draft) => (draft.chatExpiry.keepsPinned = value)),
});
const keepsLocked = computed({
  get: () => current.value.chatExpiry.keepsLocked,
  set: (value: boolean) => change((draft) => (draft.chatExpiry.keepsLocked = value)),
});
const usesArchive = computed({
  get: () => current.value.aylaUsesArchive,
  set: (value: boolean) => change((draft) => (draft.aylaUsesArchive = value)),
});

onMounted(() => retention.load());

const selectClass =
  'min-h-10 cursor-pointer appearance-none rounded-pill bg-tint py-2 pl-4 pr-10 text-sm font-medium text-heading hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
</script>

<template>
  <SettingsPage :title="RETENTION_TITLE">
    <p v-if="status === 'loading' || status === 'idle'" class="flex items-center gap-2.5 p-3 text-base text-subtle">
      {{ RETENTION_LOADING }}
    </p>
    <p v-else-if="status === 'unavailable'" class="rounded-pill bg-white p-3 text-base text-subtle">{{ RETENTION_NOT_AVAILABLE }}</p>
    <div v-else-if="status === 'failed'" class="flex flex-col items-start gap-2 p-3">
      <p role="alert" class="text-sm text-danger">{{ RETENTION_LOAD_FAILED }}</p>
      <button type="button" class="min-h-11 text-sm font-semibold text-brand hover:underline" @click="retention.load()">
        {{ RETENTION_RETRY }}
      </button>
    </div>
    <template v-else>
      <p v-if="problem" role="alert" class="px-2 text-sm text-danger">{{ problem }}</p>

      <div class="flex flex-col gap-3 rounded-pill bg-white p-3">
        <div class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
          <label :for="expiryId" class="text-base font-semibold text-heading">{{ RETENTION_EXPIRE_LABEL }}</label>
          <span class="relative">
            <select
              :id="expiryId"
              :value="current.chatExpiry.days === null ? 'none' : String(current.chatExpiry.days)"
              :class="selectClass"
              @change="chooseDays"
            >
              <option value="none">{{ RETENTION_NO_EXPIRY }}</option>
              <option v-for="days in CHAT_EXPIRY_PERIODS" :key="days" :value="String(days)">{{ getRetentionPeriod(days) }}</option>
            </select>
            <LayoutPaveIcon name="chevronDown" class="pointer-events-none absolute right-4 top-1/2 size-3 -translate-y-1/2 text-heading" aria-hidden="true" />
          </span>
        </div>
        <p class="text-xs/normal text-subtle">{{ RETENTION_EXPIRY_HINT }}</p>

        <template v-if="current.chatExpiry.days !== null">
          <hr class="border-line" />
          <div class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
            <label :for="startId" class="text-base font-semibold text-heading">{{ RETENTION_START_LABEL }}</label>
            <span class="relative">
              <select :id="startId" :value="current.chatExpiry.start" :class="selectClass" @change="chooseStart">
                <option value="last_message">{{ getRetentionStart('last_message') }}</option>
                <option value="created">{{ getRetentionStart('created') }}</option>
              </select>
              <LayoutPaveIcon name="chevronDown" class="pointer-events-none absolute right-4 top-1/2 size-3 -translate-y-1/2 text-heading" aria-hidden="true" />
            </span>
          </div>
          <SettingsSwitch v-model="keepsPinned" :title="RETENTION_KEEP_PINNED" />
          <SettingsSwitch v-model="keepsLocked" :title="RETENTION_KEEP_LOCKED" />
          <p class="text-xs/normal text-subtle">{{ RETENTION_NEVER_EXPIRES }}</p>
        </template>
      </div>

      <SettingsSwitchCard v-model="usesArchive" :title="RETENTION_AYLA_ARCHIVE" :explanation="RETENTION_AYLA_ARCHIVE_HINT" />
    </template>

    <LayoutConfirmSheet
      ref="confirm"
      :title="RETENTION_CONFIRM_TITLE"
      :message="pending ? getRetentionConfirmMessage(pending.chatExpiry) : undefined"
      :confirm-label="RETENTION_CONFIRM_BUTTON"
      @confirm="confirm"
    />
  </SettingsPage>
</template>
