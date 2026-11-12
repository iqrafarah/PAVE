<script setup lang="ts">
import type { AylaAttachment } from '~/types/ayla';

const MAX_TEXT_LENGTH = 4000;

// 'home': the large card with the actions row under it (Figma Start).
// 'chat': the one-line field in the light green tray (Figma Kluis doorzoeken).
const props = defineProps<{
  variant: 'home' | 'chat';
  isWriting: boolean;
  // While talking with Ayla the field stays as it is: the microphone mutes and the green button stops talking.
  isTalking?: boolean;
  isMuted?: boolean;
  // Shown above the field when the chat sits on a screen, such as "Kluis" (Figma 1209:55066).
  contextLabel?: string;
}>();

const emit = defineEmits<{
  send: [input: 'text' | 'voice'];
  stop: [];
  talk: [];
  mute: [];
  stopTalking: [];
  // True while files are being read, so the chat can show "Gegevens ophalen" if that takes long.
  readingFiles: [isReading: boolean];
}>();

const text = defineModel<string>('text', { required: true });
const attachments = defineModel<AylaAttachment[]>('attachments', { required: true });

const textareaRef = useTemplateRef<HTMLTextAreaElement>('textarea');
const fileInputRef = useTemplateRef<HTMLInputElement>('fileInput');
const fileError = ref<string | null>(null);
const wasDictated = ref(false);
let textBeforeDictation = '';

const dictation = useSpeechDictation((transcript) => {
  const separator = textBeforeDictation ? ' ' : '';
  text.value = `${textBeforeDictation}${separator}${transcript}`.slice(0, MAX_TEXT_LENGTH);
});

const isHome = computed(() => props.variant === 'home');
const voice = useAylaVoice();
const canTalk = ref(false);
onMounted(() => (canTalk.value = voice.isSupported()));
const canSend = computed(() => text.value.trim().length > 0);
const isAtLimit = computed(() => text.value.length >= MAX_TEXT_LENGTH);
const notice = computed(() => fileError.value ?? dictation.error.value);

function send() {
  if (!canSend.value) return;
  if (dictation.isListening.value) dictation.stop();
  emit('send', wasDictated.value ? 'voice' : 'text');
  wasDictated.value = false;
}

function handleKeydown(event: KeyboardEvent) {
  const isPlainEnter = event.key === 'Enter' && !event.shiftKey && !event.isComposing;
  if (!isPlainEnter) return;
  event.preventDefault();
  send();
}

function toggleDictation() {
  if (dictation.isListening.value) {
    dictation.stop();
    return;
  }
  textBeforeDictation = text.value.trim();
  wasDictated.value = true;
  dictation.start();
}

// ✕ in the dictation bar: the recording is thrown away and the field is as it was.
function cancelDictation() {
  dictation.stop();
  text.value = textBeforeDictation;
  wasDictated.value = false;
}

// ✓ in the dictation bar: the text stays in the field, to read and change before sending.
async function finishDictation() {
  dictation.stop();
  await nextTick();
  focus();
}

async function addFiles(files: File[]) {
  fileError.value = null;
  emit('readingFiles', true);
  try {
    for (const file of files) {
      if (attachments.value.length >= MAX_ATTACHMENTS) {
        fileError.value = AYLA_TOO_MANY_FILES;
        return;
      }
      const { attachment, error } = await readAttachment(file);
      if (error) fileError.value = error;
      if (attachment) attachments.value = [...attachments.value, attachment];
    }
  } finally {
    emit('readingFiles', false);
  }
}

function handleFileChange(event: Event) {
  const input = event.target as HTMLInputElement;
  addFiles(Array.from(input.files ?? []));
  input.value = '';
}

function removeAttachment(index: number) {
  attachments.value = attachments.value.filter((_, itemIndex) => itemIndex !== index);
  fileError.value = null;
}

function openFilePicker() {
  fileInputRef.value?.click();
}

function focus() {
  textareaRef.value?.focus();
}

defineExpose({ openFilePicker, focus });
</script>

<template>
  <div class="flex w-full flex-col items-center">
    <input
      ref="fileInput"
      type="file"
      multiple
      :accept="ATTACHMENT_ACCEPT"
      class="sr-only"
      tabindex="-1"
      aria-hidden="true"
      @change="handleFileChange"
    />
    <label for="ayla-question" class="sr-only">{{ AYLA_PLACEHOLDER }}</label>

    <!-- While dictating the bar takes the place of the text field, as on the iPhone. -->
    <AylaDictationBar
      v-if="dictation.isListening.value"
      :text="text"
      @cancel="cancelDictation"
      @done="finishDictation"
    />

    <!-- Figma Start: white card (591 x 109) on a grey card that shows the actions row. -->
    <div v-else-if="isHome" class="relative w-full max-w-147.75 pb-9.25">
      <div class="absolute inset-x-6 bottom-0 top-9.25 rounded-composer bg-bubble shadow-composer sm:inset-x-12.5">
        <AylaHomeActions class="absolute inset-x-0 bottom-0 h-9.25" @add-file="openFilePicker" />
      </div>
      <div class="relative flex min-h-27.25 flex-col rounded-composer bg-white px-4.5 pb-2.75 pt-4.25 shadow-composer focus-within:outline-2 focus-within:outline-brand">
        <div class="flex flex-1 gap-2">
          <AylaSlashIcon :blocks="4" class="mt-0.5 h-4.25 w-2.75" />
          <textarea
            id="ayla-question"
            ref="textarea"
            v-model="text"
            rows="2"
            :maxlength="MAX_TEXT_LENGTH"
            :placeholder="AYLA_PLACEHOLDER"
            aria-describedby="ayla-composer-notice"
            class="h-10 flex-1 resize-none overflow-y-auto bg-transparent text-xs font-semibold text-heading placeholder:text-subtle/40 focus:outline-none"
            @keydown="handleKeydown"
          />
        </div>
        <div class="flex items-end gap-2">
          <ul v-if="attachments.length" class="flex flex-1 flex-wrap gap-1.5" aria-label="Bijlagen">
            <li v-for="(attachment, index) in attachments" :key="attachment.name + index" class="max-w-full">
              <AylaAttachmentChip :name="attachment.name" is-removable @remove="removeAttachment(index)" />
            </li>
          </ul>
          <AylaComposerButtons
            class="ml-auto"
            :can-send="canSend"
            :is-writing="isWriting"
            :is-dictation-supported="dictation.isSupported.value"
            :is-listening="dictation.isListening.value"
            @send="send"
            @stop="emit('stop')"
            :can-talk="canTalk"
            @toggle-dictation="toggleDictation"
            @talk="emit('talk')"
            :is-talking="isTalking"
            :is-muted="isMuted"
            @mute="emit('mute')"
            @stop-talking="emit('stopTalking')"
          />
        </div>
      </div>
    </div>

    <!-- Figma Kluis doorzoeken: one-line white field (591 x 53) in the tray. -->
    <AylaTray v-else>
      <template #strip>
        <span v-if="contextLabel && !attachments.length" class="flex items-center gap-1.75 font-heading text-xs font-semibold text-heading">
          <img src="/images/ayla/pill-vault.svg" alt="" width="20.3122" height="18" />
          {{ contextLabel }}
        </span>
        <AylaAttachmentChip
          v-for="(attachment, index) in attachments"
          :key="attachment.name + index"
          :name="attachment.name"
          is-removable
          @remove="removeAttachment(index)"
        />
      </template>
      <div class="flex min-h-13.25 items-center gap-3 rounded-composer bg-white py-2 pl-4.5 pr-2.75 focus-within:outline-2 focus-within:outline-brand">
        <AylaAttachMenu @add-file="openFilePicker" />
        <AylaSlashIcon :blocks="4" class="h-4.25 w-2.75" />
        <textarea
          id="ayla-question"
          ref="textarea"
          v-model="text"
          rows="1"
          :maxlength="MAX_TEXT_LENGTH"
          :placeholder="AYLA_PLACEHOLDER"
          aria-describedby="ayla-composer-notice"
          class="h-7 min-w-0 flex-1 resize-none overflow-y-auto bg-transparent py-1 text-sm font-medium text-heading placeholder:text-subtle/40 focus:outline-none"
          @keydown="handleKeydown"
        />
        <AylaComposerButtons
          :can-send="canSend"
          :is-writing="isWriting"
          :is-dictation-supported="dictation.isSupported.value"
          :is-listening="dictation.isListening.value"
          @send="send"
          @stop="emit('stop')"
          :can-talk="canTalk"
          @toggle-dictation="toggleDictation"
          @talk="emit('talk')"
          :is-talking="isTalking"
          :is-muted="isMuted"
          @mute="emit('mute')"
          @stop-talking="emit('stopTalking')"
        />
      </div>
    </AylaTray>

    <p id="ayla-composer-notice" aria-live="polite" class="w-full max-w-147.75 px-3 text-sm">
      <span v-if="notice" class="mt-2 block text-danger">{{ notice }}</span>
      <span v-else-if="isAtLimit" class="mt-2 block text-subtle">{{ AYLA_TEXT_TOO_LONG }}</span>
    </p>
  </div>
</template>
