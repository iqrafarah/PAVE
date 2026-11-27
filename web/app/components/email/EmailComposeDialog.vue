<script setup lang="ts">
// "Nieuw bericht" (iOS EmailComposeSheet): the first e-mail to someone. The people you wrote to before are suggested in
// "Aan". After sending, the conversation opens in Meldingen like any other.
const isOpen = defineModel<boolean>('open', { required: true });

const emit = defineEmits<{
  sent: [threadId: string | null];
}>();

const email = useEmail();
const to = ref('');
const subject = ref('');
const text = ref('');
const files = ref<File[]>([]);
const isSending = ref(false);
const problem = ref<string | null>(null);
const ids = { to: useId(), people: useId(), subject: useId(), text: useId(), hint: useId() };
const fileInputRef = useTemplateRef<HTMLInputElement>('fileInput');
const discardRef = useTemplateRef<{ open: () => void }>('discard');

const people = computed(() => email.state.value.people);
const address = computed(() => email.state.value.account?.address ?? '');
const hasChanges = computed(() => Boolean(to.value.trim() || subject.value.trim() || text.value.trim() || files.value.length));

/** Closing with something written asks first, as on iOS. */
const isShown = computed({
  get: () => isOpen.value,
  set: (open) => {
    if (open || !hasChanges.value || isSending.value) isOpen.value = open;
    else discardRef.value?.open();
  },
});

watch(isOpen, (open) => {
  if (!open) return;
  to.value = '';
  subject.value = '';
  text.value = '';
  files.value = [];
  problem.value = null;
});

function addFiles(event: Event) {
  const input = event.target as HTMLInputElement;
  files.value = [...files.value, ...Array.from(input.files ?? [])];
  input.value = '';
}

function removeFile(index: number) {
  files.value = files.value.filter((_, position) => position !== index);
}

async function send() {
  const recipients = parseRecipients(to.value, people.value);
  if (!recipients?.length) {
    problem.value = EMAIL_COMPOSE_MISSING_TO;
    return;
  }
  if (!text.value.trim() && !files.value.length) {
    problem.value = EMAIL_COMPOSE_MISSING_TEXT;
    return;
  }
  if (files.value.reduce((sum, file) => sum + file.size, 0) > 15 * 1024 * 1024) {
    problem.value = EMAIL_TOO_LARGE;
    return;
  }
  isSending.value = true;
  problem.value = null;
  const result = await email.send({ to: recipients, cc: [], subject: subject.value.trim(), text: text.value, files: files.value, replyTo: null });
  isSending.value = false;
  if (result.error !== null) {
    problem.value = result.error || EMAIL_COMPOSE_FAILED;
    return;
  }
  isOpen.value = false;
  emit('sent', result.threadId);
}

const field = 'w-full rounded-field border border-field-line bg-white px-3 text-sm font-medium text-heading outline-none focus:border-brand';
const label = 'text-sm font-semibold text-heading';
</script>

<template>
  <VaultSheet v-model:open="isShown" :title="EMAIL_COMPOSE_TITLE" width="narrow">
    <form id="email-compose" class="flex flex-col gap-4 pb-2" @submit.prevent="send">
      <div class="flex flex-col gap-1.5">
        <label :for="ids.to" :class="label">{{ EMAIL_COMPOSE_TO }}</label>
        <input
          :id="ids.to"
          v-model="to"
          type="text"
          inputmode="email"
          autocomplete="off"
          :list="ids.people"
          :aria-describedby="ids.hint"
          :class="field"
          class="h-11"
        />
        <datalist :id="ids.people">
          <option v-for="person in people" :key="person.address" :value="person.address">{{ person.name ?? person.address }}</option>
        </datalist>
        <p :id="ids.hint" class="text-xs text-subtle">{{ EMAIL_COMPOSE_TO_HINT }}</p>
      </div>

      <div class="flex flex-col gap-1.5">
        <label :for="ids.subject" :class="label">{{ EMAIL_COMPOSE_SUBJECT }}</label>
        <input :id="ids.subject" v-model="subject" type="text" maxlength="300" :class="field" class="h-11" />
      </div>

      <div class="flex flex-col gap-1.5">
        <label :for="ids.text" :class="label">{{ EMAIL_COMPOSE_BODY }}</label>
        <textarea :id="ids.text" v-model="text" rows="7" :class="field" class="resize-y py-2.5" />
      </div>

      <div class="flex flex-col gap-2">
        <ul v-if="files.length" class="flex flex-wrap gap-1.5">
          <li v-for="(file, index) in files" :key="`${file.name}-${index}`" class="flex max-w-64 items-center gap-1.5 rounded-full bg-surface py-1 pl-2.5 pr-1 text-xs">
            <span translate="no" class="truncate font-medium text-heading">{{ file.name }}</span>
            <span class="shrink-0 text-subtle">{{ fileSize(file.size) }}</span>
            <button
              type="button"
              :aria-label="EMAIL_REMOVE_ATTACHMENT(file.name)"
              class="flex size-5 items-center justify-center rounded-full text-subtle hover:bg-white hover:text-heading"
              @click="removeFile(index)"
            >
              <LayoutPaveIcon name="xMark" class="size-2.5" />
            </button>
          </li>
        </ul>
        <input ref="fileInput" type="file" multiple class="sr-only" tabindex="-1" @change="addFiles" />
        <button
          type="button"
          class="flex min-h-9 items-center gap-1.5 self-start rounded-field px-2 text-sm font-semibold text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
          @click="fileInputRef?.click()"
        >
          <LayoutPaveIcon name="plus" class="size-4" />
          {{ EMAIL_ADD_ATTACHMENT }}
        </button>
      </div>

      <p v-if="address" class="text-xs text-subtle">{{ EMAIL_COMPOSE_FROM(address) }}</p>
      <p v-if="problem" role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">{{ problem }}</p>
    </form>

    <template #footer>
      <button
        type="submit"
        form="email-compose"
        :disabled="isSending"
        class="min-h-11 w-full rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
      >
        {{ isSending ? EMAIL_COMPOSE_SENDING : EMAIL_COMPOSE_SEND }}
      </button>
    </template>
  </VaultSheet>

  <LayoutConfirmSheet
    ref="discard"
    :title="EMAIL_DISCARD_TITLE"
    :confirm-label="EMAIL_DISCARD"
    :cancel-label="EMAIL_DISCARD_KEEP"
    @confirm="isOpen = false"
  />
</template>
