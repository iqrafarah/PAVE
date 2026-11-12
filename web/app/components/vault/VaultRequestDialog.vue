<script setup lang="ts">
import type { VaultItemCategory } from '~/types/vault';

// "Bevestiging aanvragen" (iOS VaultRequestConfirmationSheet): choose who confirms the evidence and how to reach them,
// and see what they would get to see. Only the front for now: the window says so before and after, and nothing is sent
// or stored.
const props = defineProps<{
  itemId: string | null;
}>();

const emit = defineEmits<{
  close: [];
}>();

type Recipient = keyof typeof VAULT_REQUEST_RECIPIENTS;
type Field = keyof typeof VAULT_REQUEST_MISSING;

const RECIPIENTS = Object.keys(VAULT_REQUEST_RECIPIENTS) as Recipient[];
const fieldClass =
  'min-h-9.75 w-full rounded-field border border-field-line bg-white px-4 text-sm font-medium text-heading placeholder:text-subtle/60 focus:border-brand focus:outline-none aria-invalid:border-danger';

const vault = useVault();
const discardRef = useTemplateRef<{ open: () => void }>('discard');
const organisationRef = useTemplateRef<HTMLInputElement>('organisation');
const emailRef = useTemplateRef<HTMLInputElement>('email');
const ids = { who: useId(), organisation: useId(), email: useId(), message: useId(), shared: useId() };

const recipient = ref<Recipient>('mentor');
const organisation = ref('');
const email = ref('');
const message = ref('');
const showsMissing = ref(false);
const isFinished = ref(false);

const item = computed(() => vault.state.value.items.find((entry) => entry.id === props.itemId) ?? null);

/** Who usually confirms this kind of evidence: a school for a diploma, an employer for an internship. */
function suggested(category: VaultItemCategory): Recipient {
  if (category === 'diplomas' || category === 'certificates' || category === 'badges') return 'school';
  if (category === 'workExperience' || category === 'internships') return 'employer';
  return 'mentor';
}

const missing = computed<Field[]>(() => {
  const fields: Field[] = [];
  if (!organisation.value.trim()) fields.push('organisation');
  // A rough check, as in a mail app: something before and after the @, and a dot in the domain.
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(email.value.trim())) fields.push('email');
  return fields;
});
const problem = (field: Field) => (showsMissing.value && missing.value.includes(field) ? VAULT_REQUEST_MISSING[field] : undefined);

const hasChanges = computed(
  () =>
    !isFinished.value &&
    Boolean(item.value) &&
    (recipient.value !== suggested(item.value!.category) ||
      organisation.value !== (item.value!.organisationName ?? '') ||
      Boolean(email.value || message.value)),
);

/** What of the evidence the person who confirms it would get to see, so nothing is shared without you knowing what. */
const sharedLines = computed(() => {
  const current = item.value;
  if (!current) return [];
  const lines = [VAULT_SHARED_TITLE(current.title, VAULT_CATEGORY_TITLES[current.category])];
  if (current.organisationName) lines.push(current.organisationName);
  const period = itemPeriod(current);
  if (period) lines.push(period);
  if (current.description) lines.push(VAULT_SHARED_DESCRIPTION);
  const documents = current.files.filter((file) => file.role === 'document').length;
  if (documents) lines.push(VAULT_SHARED_FILES(documents));
  if (current.skills.length) lines.push(VAULT_SHARED_SKILLS(current.skills.length));
  return lines;
});

const isOpen = computed({
  get: () => item.value !== null,
  set: (open) => {
    if (open) return;
    if (hasChanges.value) discardRef.value?.open();
    else emit('close');
  },
});

watch(
  () => item.value?.id,
  () => {
    if (!item.value) return;
    recipient.value = suggested(item.value.category);
    organisation.value = item.value.organisationName ?? '';
    email.value = '';
    message.value = '';
    showsMissing.value = false;
    isFinished.value = false;
  },
);

function send() {
  showsMissing.value = true;
  if (missing.value.length) {
    (missing.value[0] === 'organisation' ? organisationRef : emailRef).value?.focus();
    return;
  }
  isFinished.value = true;
}
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="VAULT_REQUEST_ACTION" width="narrow">
    <!-- Nothing was sent: said plainly, with the name of the organisation. -->
    <div v-if="isFinished" class="flex flex-col items-center gap-4.5 py-8 text-center" role="status">
      <span class="flex size-18 items-center justify-center rounded-full bg-status-pending-surface text-status-pending" aria-hidden="true">
        <VaultIcon src="/images/vault/icons/ClockSolid.svg" class="size-8" />
      </span>
      <div class="flex max-w-95 flex-col gap-2">
        <p class="font-heading text-xl font-semibold text-heading">{{ VAULT_REQUEST_NOT_SENT_TITLE }}</p>
        <p class="text-sm font-medium text-subtle">{{ VAULT_REQUEST_NOT_SENT_MESSAGE(organisation) }}</p>
      </div>
    </div>

    <form v-else class="flex flex-col gap-5.5" novalidate @submit.prevent="send">
      <div class="flex items-start gap-3 rounded-xl bg-status-pending-surface px-3.5 py-3">
        <span
          class="mt-px shrink-0 rounded-full bg-status-pending/15 px-2 py-0.5 text-[0.6875rem] font-semibold text-status-pending"
          :aria-label="VAULT_REQUEST_PREVIEW_ACCESSIBILITY"
        >
          {{ VAULT_REQUEST_PREVIEW_LABEL }}
        </span>
        <p class="text-xs font-medium text-status-pending">{{ VAULT_REQUEST_NOT_ACTIVE }}</p>
      </div>

      <div class="flex flex-col gap-2.5">
        <p :id="ids.who" class="text-sm font-semibold text-heading">{{ VAULT_REQUEST_WHO_TITLE }}</p>
        <div role="radiogroup" :aria-labelledby="ids.who" class="flex flex-col gap-2.5">
          <label
            v-for="option in RECIPIENTS"
            :key="option"
            :class="recipient === option ? 'border-drop-line bg-drop' : 'border-field-line bg-white hover:bg-surface'"
            class="flex cursor-pointer items-center gap-3 rounded-xl border p-3.5 transition-colors has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand"
          >
            <input v-model="recipient" type="radio" :value="option" name="vault-request-recipient" class="sr-only" />
            <span
              :class="recipient === option ? 'bg-brand text-white' : 'bg-drop text-brand'"
              class="flex size-10 shrink-0 items-center justify-center rounded-[0.625rem] transition-colors"
              aria-hidden="true"
            >
              <VaultIcon :src="VAULT_REQUEST_RECIPIENTS[option].icon" class="size-5" />
            </span>
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="text-sm font-semibold text-heading">{{ VAULT_REQUEST_RECIPIENTS[option].title }}</span>
              <span class="text-xs font-medium text-subtle">{{ VAULT_REQUEST_RECIPIENTS[option].example }}</span>
            </span>
            <span
              :class="recipient === option ? 'border-[6px] border-brand' : 'border-[1.5px] border-field-line'"
              class="size-5.5 shrink-0 rounded-full bg-white"
              aria-hidden="true"
            />
          </label>
        </div>
      </div>

      <VaultField
        :label="VAULT_REQUEST_RECIPIENTS[recipient].organisationLabel"
        :for="ids.organisation"
        :problem="problem('organisation')"
        :problem-id="`${ids.organisation}-problem`"
      >
        <input
          :id="ids.organisation"
          ref="organisation"
          v-model="organisation"
          type="text"
          autocomplete="organization"
          :placeholder="VAULT_REQUEST_ORGANISATION_PROMPT"
          :aria-invalid="Boolean(problem('organisation'))"
          :aria-describedby="problem('organisation') ? `${ids.organisation}-problem` : undefined"
          :class="fieldClass"
        />
      </VaultField>

      <VaultField :label="VAULT_REQUEST_EMAIL_TITLE" :for="ids.email" :problem="problem('email')" :problem-id="`${ids.email}-problem`">
        <input
          :id="ids.email"
          ref="email"
          v-model="email"
          type="email"
          autocomplete="email"
          autocapitalize="off"
          spellcheck="false"
          :placeholder="VAULT_REQUEST_EMAIL_PROMPT"
          :aria-invalid="Boolean(problem('email'))"
          :aria-describedby="problem('email') ? `${ids.email}-problem` : undefined"
          :class="fieldClass"
        />
      </VaultField>

      <VaultField :label="VAULT_REQUEST_MESSAGE_TITLE" :for="ids.message" is-optional>
        <textarea
          :id="ids.message"
          v-model="message"
          rows="3"
          maxlength="1000"
          :placeholder="VAULT_REQUEST_MESSAGE_PROMPT"
          :class="fieldClass"
          class="resize-y py-3"
        />
      </VaultField>

      <div class="flex flex-col gap-2.5">
        <p :id="ids.shared" class="text-sm font-semibold text-heading">{{ VAULT_REQUEST_SHARED_TITLE }}</p>
        <ul :aria-labelledby="ids.shared" class="flex flex-col gap-2.5 rounded-xl border border-field-line bg-white p-3.5">
          <li v-for="line in sharedLines" :key="line" class="flex items-baseline gap-2.5 text-xs font-medium text-heading">
            <LayoutPaveIcon name="check" class="size-3.5 shrink-0 translate-y-0.5 text-brand" />
            {{ line }}
          </li>
        </ul>
      </div>
    </form>

    <template #footer>
      <button
        type="button"
        class="min-h-10 w-full rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="isFinished ? emit('close') : send()"
      >
        {{ isFinished ? VAULT_ADD_CLOSE : VAULT_REQUEST_SEND }}
      </button>
    </template>

    <LayoutConfirmSheet
      ref="discard"
      :title="VAULT_REQUEST_DISCARD_TITLE"
      :confirm-label="VAULT_REQUEST_DISCARD_CONFIRM"
      :cancel-label="VAULT_REQUEST_DISCARD_KEEP"
      @confirm="emit('close')"
    />
  </VaultSheet>
</template>
