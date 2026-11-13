<script setup lang="ts">
import type { AylaAttachment, AylaErrorCode, AylaScreen } from '~/types/ayla';

const props = defineProps<{
  // The screen this chat sits on, such as the vault: the chatbox then says so and Ayla hears it with the question.
  screen?: AylaScreen;
}>();

interface ErrorAction {
  label: string;
  to: string;
}

const ERROR_ACTIONS: Partial<Record<AylaErrorCode, ErrorAction>> = {
  not_signed_in: { label: AYLA_SIGN_IN_AGAIN_ACTION, to: '/login' },
  insufficient_aal: { label: AYLA_ENTER_CODE_ACTION, to: MFA_VERIFY_PATH },
  conversation_not_found: { label: AYLA_NEW_CHAT, to: '/' },
};

const conversation = useAylaConversation();
const voice = useAylaVoice();
const memory = useAylaMemory();
const vaultAdd = useVaultAdd();
const { readDraft, saveDraft } = useAylaDraft();

const text = ref('');
const attachments = ref<AylaAttachment[]>([]);
const isComposerReading = ref(false);
const composerRef = useTemplateRef<{ openFilePicker: () => void; focus: () => void }>('composer');

const state = computed(() => conversation.state.value);
const itemContext = computed(() => conversation.itemContext.value);
const conversationId = computed(() => state.value.conversationId);
const hasMessages = computed(() => state.value.messages.length > 0);
const latestAnswer = computed(() => {
  const last = state.value.messages.at(-1);
  return last?.role === 'ayla' ? last : null;
});
// Like iOS (phase .thinking): the small blocks with "Ayla denkt na…" only until Ayla's first words arrive.
const isThinking = computed(() => state.value.isWriting && !latestAnswer.value?.text);
// Ayla is reading what the user attached: the one wait that gets the big "Gegevens ophalen" loader.
const isReadingAttachment = computed(() => {
  const question = state.value.messages.at(-2);
  return isThinking.value && question?.role === 'user' && question.attachmentNames.length > 0;
});
const isReadingFiles = computed(() => isComposerReading.value || isReadingAttachment.value);
// The vault shows under the chatbox until a chat starts.
const isFloating = computed(() => Boolean(props.screen) && !hasMessages.value && !isReadingFiles.value);
const errorMessage = computed(() => (state.value.error ? getAylaErrorMessage(state.value.error) : null));
const errorAction = computed(() => (state.value.error ? ERROR_ACTIONS[state.value.error] : undefined));
// The user's question that Ayla's newest answer is about.
const askedText = computed(() => {
  const question = state.value.messages.at(-2);
  return latestAnswer.value && question?.role === 'user' ? question.text : '';
});
const isVaultOffer = computed(() => offersToAddEvidence(latestAnswer.value?.reply, askedText.value));
const openQuestion = computed(() => {
  if (state.value.isWriting) return null;
  const question = getReplyQuestion(latestAnswer.value?.reply, askedText.value);
  return question && question.choices.length >= 2 ? question : null;
});

function restoreFailed(failedText: string | null, failedAttachments: AylaAttachment[]) {
  if (failedText === null) return;
  text.value = failedText;
  attachments.value = failedAttachments;
}

async function send(questionText: string, input: 'text' | 'voice' = 'text') {
  const sentAttachments = attachments.value;
  const startedWithoutConversation = !conversationId.value;
  conversation.redoError.value = null;
  text.value = '';
  attachments.value = [];

  const { failedText, failedAttachments } = await conversation.send({
    text: questionText,
    attachments: sentAttachments,
    input,
    ...(props.screen ? { context: { screen: props.screen } } : {}),
    onConversationStarted(newId) {
      if (startedWithoutConversation) saveDraft(null, '');
      navigateTo(`/ayla/${newId}`);
    },
  });
  restoreFailed(failedText, failedAttachments);
}

// While talking the field stays the same; a typed question is answered out loud too.
function sendWhileTalking() {
  voice.sendTyped(text.value);
  text.value = '';
}

// "Ja" to Ayla's "Wil je iets toevoegen?" opens Kluis aanvullen; the answer still goes to Ayla, as in the design.
function choose(label: string) {
  const reply = latestAnswer.value?.reply;
  if (isVaultOffer.value && isYesChoice(label)) vaultAdd.open({ suggestedSkills: getSuggestedSkills(reply) });
  send(label);
}

function clearItemContext() {
  conversation.clearItemContext();
  composerRef.value?.focus();
}

function openFilePicker() {
  composerRef.value?.openFilePicker();
}

watch(conversationId, (id, previousId) => {
  // Moving from the home screen to the new chat keeps what is being typed.
  if (previousId === null && id && text.value) return;
  text.value = readDraft(id);
});
watch(text, (value) => saveDraft(conversationId.value, value));
watch(conversation.questionToEdit, async (question) => {
  if (question === null) return;
  text.value = question;
  conversation.questionToEdit.value = null;
  await nextTick();
  composerRef.value?.focus();
});

onMounted(() => {
  text.value = readDraft(conversationId.value);
  // The memory cards under replies need the notes the user already has.
  if (memory.state.value.status === 'idle') memory.load();
});

defineExpose({ openFilePicker });
</script>

<template>
  <div class="relative flex min-h-0 flex-1 flex-col">
    <AylaCanvas
      v-if="hasMessages || isReadingFiles"
      :latest-answer="latestAnswer"
      :is-writing="state.isWriting"
      :is-reading-files="isReadingFiles"
      :conversation-id="conversationId"
    />
    <slot v-else name="empty" />

    <!-- Over a screen such as the vault, the chatbox floats: what is behind it stays visible around it. -->
    <div
      :class="isFloating ? 'pointer-events-none absolute inset-x-0 bottom-0 *:pointer-events-auto' : 'relative'"
      class="flex flex-col items-center px-4 pb-8.25"
    >
      <!-- Only while talking is on: Ayla's small orb, above her answer and the text field. -->
      <AylaVoiceDock v-if="voice.isActive.value" class="relative mb-3" />
      <AylaLatestBubble
        v-if="latestAnswer?.text"
        :key="latestAnswer.id"
        class="relative mb-2.5"
        :message="latestAnswer"
        :question="openQuestion?.text"
        :can-answer-again="!state.isWriting"
        @answer-again="conversation.changeLastTurn('answerAgain')"
      />
      <AylaPixelLoader
        v-if="isThinking && !isReadingAttachment && !voice.isActive.value"
        class="relative mb-10.25"
        mode="thinking"
        :label="AYLA_THINKING"
      />
      <div v-if="errorMessage" class="relative mb-6 flex flex-col items-center gap-3 px-4">
        <AylaPixelLoader mode="failed" :label="errorMessage" />
        <NuxtLink
          v-if="errorAction"
          :to="errorAction.to"
          class="relative rounded-lg bg-brand px-3 py-2 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          {{ errorAction.label }}
        </NuxtLink>
      </div>
      <AylaNotice v-if="voice.session.value.problem" class="relative mb-3 w-full max-w-147.75" :message="voice.session.value.problem" />
      <AylaNotice
        v-if="conversation.redoError.value"
        class="relative mb-3 w-full max-w-147.75"
        :message="conversation.redoError.value"
      />

      <AylaContextChip v-if="itemContext" class="relative mb-2.5" :title="itemContext.title" @clear="clearItemContext" />
      <AylaChoiceBar
        v-if="openQuestion && !voice.isActive.value"
        class="relative"
        :question="openQuestion.text"
        :choices="openQuestion.choices"
        :is-about-vault="isVaultOffer"
        @choose="choose"
      />
      <AylaComposer
        v-else
        ref="composer"
        v-model:text="text"
        v-model:attachments="attachments"
        class="relative"
        :variant="hasMessages || screen ? 'chat' : 'home'"
        :context-label="screen === 'vault' ? AYLA_VAULT_LABEL : undefined"
        :is-writing="state.isWriting"
        :is-talking="voice.isActive.value"
        :is-muted="voice.session.value.isMuted"
        @send="voice.isActive.value ? sendWhileTalking() : send(text, $event)"
        @stop="conversation.stop"
        @talk="voice.start"
        @mute="voice.toggleMute"
        @stop-talking="voice.stop"
        @reading-files="isComposerReading = $event"
      />
    </div>

    <!-- Announces Ayla's answer once it is complete, not every word while she writes. -->
    <p class="sr-only" aria-live="polite">{{ state.announcement }}</p>
  </div>
</template>
