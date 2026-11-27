<script setup lang="ts">
import type { EmailMessage } from '#shared/types/email';

// An e-mail conversation as a chat (iOS EmailThreadScreen): your messages on the right, theirs on the left, only the new
// part of each mail, the files under it, and a reply at the bottom: to everyone on the last message, or only to its
// sender. Opening it marks it read, in the mailbox too.
const props = defineProps<{
  threadId: string;
}>();

const emit = defineEmits<{
  back: [];
  delete: [];
}>();

const email = useEmail();
const text = ref('');
const files = ref<File[]>([]);
const toEveryone = ref(true);
const isSending = ref(false);
const problem = ref<string | null>(null);
const loadProblem = ref<string | null>(null);
const isLoadingBodies = ref(false);
const ids = { text: useId(), files: useId() };
const scrollerRef = useTemplateRef<HTMLElement>('scroller');
const fileInputRef = useTemplateRef<HTMLInputElement>('fileInput');
const deleteRef = useTemplateRef<{ open: () => void }>('confirmDelete');

const thread = computed(() => email.threadById(props.threadId));
const me = computed(() => email.state.value.account?.address ?? '');
const subject = computed(() => (thread.value ? threadSubject(thread.value) : ''));
const names = computed(() => (thread.value ? participantNames(thread.value) : ''));
const isGroup = computed(() => (thread.value ? participants(thread.value).length > 1 : false));
const latest = computed(() => (thread.value ? latestMessage(thread.value) : null));
const everyone = computed(() => (latest.value ? replyRecipients(latest.value, me.value, true) : { to: [], cc: [] }));
const onlySender = computed(() => (latest.value ? replyRecipients(latest.value, me.value, false) : { to: [], cc: [] }));
const canChooseRecipients = computed(() => everyone.value.to.length + everyone.value.cc.length > 1);
const recipients = computed(() => (toEveryone.value || !canChooseRecipients.value ? everyone.value : onlySender.value));
const recipientsLabel = computed(() => [...recipients.value.to, ...recipients.value.cc].map(displayName).join(', '));
const senderName = computed(() => (onlySender.value.to[0] ? displayName(onlySender.value.to[0]) : ''));
const filesSize = computed(() => files.value.reduce((sum, file) => sum + file.size, 0));
const canSend = computed(() => (text.value.trim() || files.value.length) && recipients.value.to.length && !isSending.value);

function bodyOf(message: EmailMessage) {
  return email.state.value.bodies[message.id] ?? null;
}

function scrollToEnd() {
  nextTick(() => {
    const scroller = scrollerRef.value;
    if (scroller) scroller.scrollTop = scroller.scrollHeight;
  });
}

async function open() {
  const current = thread.value;
  if (!current) return;
  loadProblem.value = null;
  isLoadingBodies.value = true;
  email.markRead(current.id);
  const { error } = await email.loadBodies(current);
  isLoadingBodies.value = false;
  loadProblem.value = error;
  scrollToEnd();
}

function addFiles(event: Event) {
  const input = event.target as HTMLInputElement;
  files.value = [...files.value, ...Array.from(input.files ?? [])];
  input.value = '';
}

function removeFile(index: number) {
  files.value = files.value.filter((_, position) => position !== index);
}

async function send() {
  const message = latest.value;
  if (!canSend.value || !message) return;
  if (filesSize.value > 15 * 1024 * 1024) {
    problem.value = EMAIL_TOO_LARGE;
    return;
  }
  isSending.value = true;
  problem.value = null;
  const result = await email.send({
    to: recipients.value.to,
    cc: recipients.value.cc,
    subject: replySubject(message.subject),
    text: text.value,
    files: files.value,
    replyTo: message,
  });
  isSending.value = false;
  if (result.error !== null) {
    problem.value = result.error || EMAIL_REPLY_FAILED;
    return;
  }
  text.value = '';
  files.value = [];
  await open();
}

/** Enter with Ctrl or ⌘ sends, as in Mail; Enter alone makes a new line. */
function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    send();
  }
}

watch(
  () => props.threadId,
  () => {
    text.value = '';
    files.value = [];
    problem.value = null;
    toEveryone.value = true;
    open();
  },
  { immediate: true },
);

// New mail in this conversation (a refresh) is read at once while it is open.
watch(
  () => thread.value?.messages.length,
  (count, previous) => {
    if (previous !== undefined && count !== previous) open();
  },
);

const iconButton =
  'flex size-9 items-center justify-center rounded-lg text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand';
</script>

<template>
  <LayoutEmptyState
    v-if="!thread"
    icon="mailOpen"
    :title="EMAIL_THREAD_NOT_FOUND_TITLE"
    :message="EMAIL_THREAD_NOT_FOUND_MESSAGE"
    class="h-full justify-center"
  />
  <section v-else class="flex h-full min-h-0 flex-col" :aria-label="names">
    <header class="flex shrink-0 items-center gap-2 border-b border-card-line px-3 py-3 sm:px-5">
      <button type="button" :aria-label="EMAIL_BACK" :class="iconButton" class="lg:hidden" @click="emit('back')">
        <LayoutPaveIcon name="arrowLeft" class="size-4" />
      </button>
      <NotificationKindIcon kind="email" />
      <div class="min-w-0 flex-1">
        <h2 translate="no" class="truncate text-base font-semibold text-heading">{{ names }}</h2>
        <p v-if="subject" translate="no" class="truncate text-xs text-subtle">{{ subject }}</p>
      </div>
      <button type="button" :aria-label="EMAIL_DELETE_THREAD" :title="EMAIL_DELETE_THREAD" :class="iconButton" class="hover:text-danger" @click="deleteRef?.open()">
        <LayoutPaveIcon name="trash" class="size-4" />
      </button>
    </header>

    <div ref="scroller" class="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto px-3 py-4 sm:px-5" :aria-busy="isLoadingBodies">
      <p v-if="loadProblem" role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">{{ loadProblem }}</p>
      <article
        v-for="message in thread.messages"
        :key="message.id"
        :class="message.isFromMe ? 'items-end self-end' : 'items-start self-start'"
        class="flex max-w-[85%] flex-col gap-1"
      >
        <span v-if="!message.isFromMe && isGroup" translate="no" class="px-1 text-xs font-medium text-subtle">{{ displayName(message.from) }}</span>
        <div
          :class="message.isFromMe ? 'rounded-br-md bg-brand text-white' : 'rounded-bl-md bg-surface text-heading'"
          class="rounded-2xl px-3.5 py-2.5 text-sm"
        >
          <p v-if="bodyOf(message)" translate="no" class="whitespace-pre-wrap break-words">{{ bodyOf(message)!.text }}</p>
          <p v-else class="opacity-70" role="status">{{ EMAIL_MESSAGE_LOADING }}…</p>
        </div>
        <ul v-if="bodyOf(message)?.attachments.length" class="flex flex-wrap gap-1.5" :class="message.isFromMe ? 'justify-end' : ''">
          <li v-for="file in bodyOf(message)!.attachments" :key="file.index">
            <a
              :href="email.attachmentUrl(message, file.index)"
              :download="file.name"
              :aria-label="EMAIL_ATTACHMENT_OPEN(file.name)"
              class="flex max-w-64 items-center gap-2 rounded-xl border border-card-border bg-white px-2.5 py-2 text-xs hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
            >
              <LayoutPaveIcon name="download" class="size-3.5 shrink-0 text-brand" />
              <span translate="no" class="truncate font-medium text-heading">{{ file.name }}</span>
              <span class="shrink-0 text-subtle">{{ fileSize(file.size) }}</span>
            </a>
          </li>
        </ul>
        <time :datetime="message.date" class="px-1 text-[0.6875rem] text-subtle">
          {{ message.isFromMe ? `${EMAIL_SENT_LABEL} · ` : '' }}{{ messageTime(message.date) }}
        </time>
      </article>
    </div>

    <form class="shrink-0 border-t border-card-line px-3 py-3 sm:px-5" @submit.prevent="send">
      <div class="mb-2 flex flex-wrap items-center gap-1.5 text-xs text-subtle">
        <template v-if="canChooseRecipients">
          <button
            type="button"
            :aria-pressed="toEveryone"
            :class="toEveryone ? 'bg-tint text-brand' : 'hover:bg-surface'"
            class="rounded-full px-2.5 py-1 font-medium focus-visible:outline-2 focus-visible:outline-brand"
            @click="toEveryone = true"
          >
            {{ EMAIL_REPLY_ALL }}
          </button>
          <button
            type="button"
            :aria-pressed="!toEveryone"
            :class="!toEveryone ? 'bg-tint text-brand' : 'hover:bg-surface'"
            class="rounded-full px-2.5 py-1 font-medium focus-visible:outline-2 focus-visible:outline-brand"
            @click="toEveryone = false"
          >
            {{ EMAIL_REPLY_ONLY(senderName) }}
          </button>
        </template>
        <span class="truncate">{{ EMAIL_TO(recipientsLabel) }}</span>
      </div>

      <ul v-if="files.length" class="mb-2 flex flex-wrap gap-1.5">
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

      <div class="flex items-end gap-2">
        <input :id="ids.files" ref="fileInput" type="file" multiple class="sr-only" tabindex="-1" @change="addFiles" />
        <button type="button" :aria-label="EMAIL_ADD_ATTACHMENT" :title="EMAIL_ADD_ATTACHMENT" :class="iconButton" @click="fileInputRef?.click()">
          <LayoutPaveIcon name="plus" class="size-4.5" />
        </button>
        <label :for="ids.text" class="sr-only">{{ EMAIL_MESSAGE_PLACEHOLDER }}</label>
        <textarea
          :id="ids.text"
          v-model="text"
          rows="2"
          :placeholder="EMAIL_MESSAGE_PLACEHOLDER"
          class="max-h-48 min-h-11 flex-1 resize-y rounded-field border border-field-line bg-white px-3 py-2.5 text-sm text-heading outline-none focus:border-brand"
          @keydown="handleKeydown"
        />
        <button
          type="submit"
          :disabled="!canSend"
          :aria-label="isSending ? EMAIL_SENDING : EMAIL_SEND"
          class="min-h-11 rounded-field bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        >
          {{ isSending ? `${EMAIL_SENDING}…` : EMAIL_SEND }}
        </button>
      </div>
      <p v-if="problem" role="alert" class="mt-2 text-xs text-danger">{{ problem }}</p>
    </form>
  </section>

  <LayoutConfirmSheet
    ref="confirmDelete"
    :title="EMAIL_DELETE_TITLE"
    :message="EMAIL_DELETE_MESSAGE"
    :confirm-label="EMAIL_DELETE"
    @confirm="emit('delete')"
  />
</template>
