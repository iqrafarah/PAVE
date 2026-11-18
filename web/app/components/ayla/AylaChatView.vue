<script setup lang="ts">
import type { AylaAttachment, AylaErrorCode, AylaScreen, AylaVaultItemProposal } from '~/types/ayla';

const props = defineProps<{
  // The screen this chat sits on, such as the vault: the chatbox then says so and Ayla hears it with the question.
  screen?: AylaScreen;
  // A new chat started here belongs to this project.
  projectId?: string;
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
const vault = useVault();
const projects = useAylaProjects();
const router = useRouter();
// A chat started with "Nieuwe chat" on a project belongs to it; the chip above the chatbox says so, ✕ undoes it.
const newChatProject = computed(() =>
  conversationId.value ? null : (projects.find(projects.state.value.newChatProjectId ?? '') ?? null),
);
// "Nieuwe vergrendelde chat": the chip says so, and the chat is locked as soon as it exists.
const lock = useAylaChatLock();
const isNewChatLocked = computed(() => !conversationId.value && lock.state.value.isNewChatLocked);
const chatProjectId = computed(() => props.projectId ?? newChatProject.value?.id);
const { readDraft, saveDraft } = useAylaDraft();

const text = ref('');
const attachments = ref<AylaAttachment[]>([]);
const isComposerReading = ref(false);
const composerRef = useTemplateRef<{ openFilePicker: () => void; focus: () => void }>('composer');
const pickerRef = useTemplateRef<{ open: () => void }>('picker');
// The files sent in this chat, so "Zet in de kluis" takes the same files along (iOS keeps them for the chat).
// After a Ja Ayla saves it herself (iOS): busy while she does, then what she added.
const isSavingToVault = ref(false);
// The item Ayla just put in the vault, for her follow-up question (iOS followUp): a Ja to "Wil je er een foto bij doen?"
// picks photos for it, a Ja to "Wil je iemand vragen dit te bevestigen?" opens asking for it.
// Per chat (by id; a new chat under ''), so it survives the move from the home screen to /ayla/<id>.
const addedByChat = useState<Record<string, { itemId: string; title: string; files?: string[] }>>('ayla-last-added', () => ({}));
const lastAdded = computed({
  get: () => addedByChat.value[conversationId.value ?? ''] ?? null,
  set: (added: { itemId: string; title: string; files?: string[] } | null) => {
    const key = conversationId.value ?? '';
    const next = { ...addedByChat.value };
    if (added) next[key] = added;
    else delete next[key];
    addedByChat.value = next;
  },
});
const confirmItemId = ref<string | null>(null);
const followUpPhotosRef = useTemplateRef<HTMLInputElement>('followUpPhotos');
const followUpProblem = ref<string | null>(null);
// After a save from the chat without a logo or cover: the chat asks for them, as the form would show them.
const missingLook = ref<{ logo: boolean; cover: boolean } | null>(null);
const lookPickerRef = useTemplateRef<HTMLInputElement>('lookPicker');
const lookRole = ref<'logo' | 'cover'>('logo');

// How tall the chatbox with Ayla's answer is where it floats over a screen: the screen keeps that much room at the
// bottom, so its last row can be scrolled above it.
const floatingRef = useTemplateRef<HTMLDivElement>('floating');
const floatHeight = ref(0);
let floatObserver: ResizeObserver | null = null;
onMounted(() => {
  if (!floatingRef.value || typeof ResizeObserver === 'undefined') return;
  floatObserver = new ResizeObserver(([entry]) => (floatHeight.value = Math.ceil(entry?.borderBoxSize?.[0]?.blockSize ?? entry?.contentRect.height ?? 0)));
  floatObserver.observe(floatingRef.value);
});
onBeforeUnmount(() => floatObserver?.disconnect());

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
const isFloating = computed(() => Boolean(props.screen));
const errorMessage = computed(() => (state.value.error ? getAylaErrorMessage(state.value.error) : null));
const errorAction = computed(() => (state.value.error ? ERROR_ACTIONS[state.value.error] : undefined));
// The user's question that Ayla's newest answer is about.
const askedText = computed(() => {
  const question = state.value.messages.at(-2);
  return latestAnswer.value && question?.role === 'user' ? question.text : '';
});
// Ayla's answer to "Toegevoegd aan mijn kluis: …" or "Ik heb … foto's toegevoegd aan …": her follow-up about that item.
// Asking someone to confirm it may also come one answer later, after a Nee to the photo: that is still about this item.
const isFollowUp = computed(
  () =>
    Boolean(lastAdded.value) &&
    (isAppVaultMessage(askedText.value) || /bevestig/i.test(lastQuestionSentence(latestAnswer.value?.text ?? '') ?? '')),
);
// Never an offer to add again right after something was added: Ja would save it twice.
const isVaultOffer = computed(() => !isAppVaultMessage(askedText.value) && offersToAddEvidence(latestAnswer.value?.reply, askedText.value));
const openQuestion = computed(() => {
  if (isSavingToVault.value) return null;
  if (state.value.isWriting) {
    // Her words already end with a question for Ja or Nee: the buttons come now, not after the rest of her answer.
    // Not for putting something in the vault: that only comes once her whole answer is in, so nothing is saved while
    // she is still asking or finishing what she knows about it.
    const words = latestAnswer.value?.text ?? '';
    const last = lastQuestionSentence(words);
    const isAboutVault = /kluis/i.test(last ?? '');
    return last && !isAboutVault && words.trimEnd().endsWith('?') && endsWithYesNoQuestion(words)
      ? { text: last, choices: YES_NO }
      : null;
  }
  const question = getReplyQuestion(latestAnswer.value?.reply, askedText.value);
  return question && question.choices.length >= 2 ? question : null;
});
/**
 * What the tray under the chat asks, one thing at a time: after a save without a logo or cover, that first; Ayla's offer
 * to add something as "Ayla vult het in", "Zelf invullen" or "Nee"; otherwise her own question.
 */
const trayQuestion = computed(() => {
  if (missingLook.value && lastAdded.value && !isSavingToVault.value) {
    return {
      text: AYLA_LOOK_MISSING(missingLook.value.logo, missingLook.value.cover),
      caption: `${AYLA_ADDED_CAPTION(lastAdded.value.title)} ${AYLA_LOOK_MISSING(missingLook.value.logo, missingLook.value.cover)}`,
      choices: [
        ...(missingLook.value.logo ? [{ id: 'logo', label: AYLA_LOOK_LOGO }] : []),
        ...(missingLook.value.cover ? [{ id: 'cover', label: AYLA_LOOK_COVER }] : []),
        { id: 'done', label: AYLA_LOOK_DONE },
      ],
    };
  }
  const question = openQuestion.value;
  if (!question) return null;
  const isYesNo = question.choices.some((choice) => isYesChoice(choice.label));
  if (isVaultOffer.value && isYesNo) {
    return {
      text: question.text,
      caption: undefined,
      choices: [
        { id: 'ayla', label: AYLA_FILL_BY_AYLA },
        { id: 'self', label: AYLA_FILL_MYSELF },
        { id: 'no', label: 'Nee' },
      ],
    };
  }
  return { ...question, caption: undefined };
});
const YES_NO = [
  { id: 'yes', label: 'Ja' },
  { id: 'no', label: 'Nee' },
];
// A choice made while Ayla was still finishing her answer, handled as soon as it is complete.
const pendingChoice = ref<string | null>(null);
watch(
  () => state.value.isWriting,
  (isWriting) => {
    if (isWriting || pendingChoice.value === null) return;
    const label = pendingChoice.value;
    pendingChoice.value = null;
    choose(label);
  },
);

function restoreFailed(failedText: string | null, failedAttachments: AylaAttachment[]) {
  if (failedText === null) return;
  text.value = failedText;
  attachments.value = failedAttachments;
}

/** What you type and send: a short yes to "Wil je dit aan je kluis toevoegen?" saves it, as Ja does (iOS isConfirmation). */
function sendTyped(questionText: string, input: 'text' | 'voice' = 'text') {
  const isYesToVault =
    !attachments.value.length && isVaultOffer.value && asksToPutInVault(latestAnswer.value?.reply) && isConfirmation(questionText);
  if (!isYesToVault) return send(questionText, input);
  text.value = '';
  addToVault(questionText.trim(), getSuggestedSkills(latestAnswer.value?.reply), latestAnswer.value?.reply?.proposedAction?.vaultItem);
}

async function send(questionText: string, input: 'text' | 'voice' = 'text') {
  const sentAttachments = attachments.value;
  rememberFiles(sentAttachments);
  const startedWithoutConversation = !conversationId.value;
  // Decided when sending, so nothing that happens while Ayla answers can drop it.
  const shouldLock = isNewChatLocked.value;
  conversation.redoError.value = null;
  text.value = '';
  attachments.value = [];
  // Without new files, the ones sent earlier in this chat go along again, so Ayla keeps seeing the photo.
  const carriedAttachments = sentAttachments.length ? [] : await chatAttachmentsOf(conversationId.value);

  const { failedText, failedAttachments } = await conversation.send({
    text: questionText,
    attachments: sentAttachments,
    carriedAttachments,
    input,
    ...(props.screen ? { context: { screen: props.screen } } : {}),
    ...(chatProjectId.value ? { projectId: chatProjectId.value } : {}),
    onConversationStarted(newId) {
      moveNewChatFiles(newId);
      if (startedWithoutConversation) saveDraft(null, '');
      if (chatProjectId.value) projects.setMembership(newId, chatProjectId.value);
      if (shouldLock) lockNewChat(newId);
      projects.state.value.newChatProjectId = null;
      lock.state.value.isNewChatLocked = false;
      // On a screen such as the vault the chat stays where it was opened; only the home screen moves to /ayla/<id>.
      if (!props.screen) navigateTo(`/ayla/${newId}`);
      else navigateTo({ query: { ...router.currentRoute.value.query, chat: newId } }, { replace: true });
    },
  });
  restoreFailed(failedText, failedAttachments);
}

async function lockNewChat(id: string) {
  const { isFailed } = await lock.lockChat(id);
  if (isFailed) projects.showNotice(AYLA_LOCK_FAILED, true);
}

// While talking the field stays the same; a typed question is answered out loud too.
function sendWhileTalking() {
  voice.sendTyped(text.value);
  text.value = '';
}

// "Ja" to Ayla's "Wil je iets toevoegen?" opens Kluis aanvullen; the answer still goes to Ayla, as in the design.
function choose(label: string) {
  if (state.value.isWriting) {
    pendingChoice.value = label;
    return;
  }
  const reply = latestAnswer.value?.reply;
  if (missingLook.value && lastAdded.value) {
    if (label === AYLA_LOOK_LOGO) pickLook('logo');
    else if (label === AYLA_LOOK_COVER) pickLook('cover');
    else finishLook();
    return;
  }
  if (isVaultOffer.value && label === AYLA_FILL_MYSELF) {
    fillMyself(reply?.proposedAction?.vaultItem);
    return;
  }
  if (isFollowUp.value && isYesChoice(label) && answerFollowUp(label)) return;
  if (isVaultOffer.value && (label === AYLA_FILL_BY_AYLA || isYesChoice(label))) {
    addToVault(label, getSuggestedSkills(reply), reply?.proposedAction?.vaultItem);
    return;
  }
  send(label);
}

/**
 * Ja to adding it to the vault (iOS addEvidenceForUser): Ayla reads the chat's files and saves the item herself. The form
 * only opens, already filled in, when something required is missing, she sees more than one item, or it fails; without
 * files there is nothing for her to read, so the form opens as before.
 */
/** The files Ayla named for this item; else the ones from the latest message with files (what she just looked at). */
async function itemFiles(chatItem?: AylaVaultItemProposal) {
  const named = new Set(chatItem?.attachments ?? []);
  const namedFiles = (await chatFilesOf(conversationId.value)).filter((file) => named.has(file.name));
  return namedFiles.length ? namedFiles : await latestChatFiles(conversationId.value);
}

/** "Zelf invullen": the form opens empty with the chat's files attached; Ayla reads and fills in nothing. */
async function fillMyself(chatItem?: AylaVaultItemProposal) {
  const files = await itemFiles(chatItem);
  vaultAdd.open({ documents: files, fillsMyself: true });
}

/** The look step is done: only now does Ayla hear it is in the vault, and she asks what is next. */
function finishLook() {
  const added = lastAdded.value;
  missingLook.value = null;
  if (added) send(AYLA_VAULT_ADDED_MESSAGE(added.title, added.files));
}

async function addToVault(label: string, suggestedSkills: string[], chatItem?: AylaVaultItemProposal) {
  if (isSavingToVault.value) return;
  const files = await itemFiles(chatItem);
  if (!files.length && !chatItem?.title) {
    vaultAdd.open({ suggestedSkills });
    send(label);
    return;
  }
  isSavingToVault.value = true;
  const result = await vaultAdd.saveFromChat(files, suggestedSkills, chatItem);
  isSavingToVault.value = false;
  if (result.status === 'saved') {
    lastAdded.value = { itemId: result.itemId, title: result.title, files: files.map((file) => file.name) };
    // These files are in the vault now: they no longer go along with the next questions.
    clearLatestChatFiles(conversationId.value);
    // No logo or cover: the tray asks for them first; Ayla hears it is saved once that is done.
    if (!result.hasLogo || !result.hasCover) missingLook.value = { logo: !result.hasLogo, cover: !result.hasCover };
    else send(AYLA_VAULT_ADDED_MESSAGE(result.title, lastAdded.value?.files));
  } else {
    vaultAdd.open({ suggestedSkills, documents: files, prefill: result.prefill });
  }
}

/** Ja to Ayla's follow-up: photos for the item, or asking someone to confirm it. False when it is neither. */
function answerFollowUp(label: string) {
  const question = (lastQuestionSentence(latestAnswer.value?.text ?? '') ?? '').toLowerCase();
  if (question.includes('foto')) {
    followUpProblem.value = null;
    followUpPhotosRef.value?.click();
    return true;
  }
  if (question.includes('bevestig') && lastAdded.value) {
    confirmItemId.value = lastAdded.value.itemId;
    send(label);
    return true;
  }
  return false;
}

function pickLook(role: 'logo' | 'cover') {
  lookRole.value = role;
  followUpProblem.value = null;
  lookPickerRef.value?.click();
}

/** The picture you chose becomes the logo or the cover of the item that was just added. */
async function addLook(event: Event) {
  const input = event.target as HTMLInputElement;
  const picture = input.files?.[0];
  input.value = '';
  const added = lastAdded.value;
  if (!picture || !added || !missingLook.value) return;
  try {
    await vault.attach(added.itemId, picture, lookRole.value);
    missingLook.value = { ...missingLook.value, [lookRole.value]: false };
    vault.load();
    if (!missingLook.value.logo && !missingLook.value.cover) finishLook();
  } catch {
    followUpProblem.value = AYLA_LOOK_FAILED;
  }
}

/** The chosen photos go with the item that was just added, and Ayla hears how many. */
async function addFollowUpPhotos(event: Event) {
  const input = event.target as HTMLInputElement;
  const photos = Array.from(input.files ?? []);
  input.value = '';
  const added = lastAdded.value;
  if (!photos.length || !added) return;
  isSavingToVault.value = true;
  let count = 0;
  for (const photo of photos.slice(0, MAX_DOCUMENTS)) {
    try {
      await vault.attach(added.itemId, photo, 'document');
      count += 1;
    } catch {
      followUpProblem.value = AYLA_PHOTOS_FAILED;
    }
  }
  isSavingToVault.value = false;
  if (!count) return;
  vault.load();
  send(AYLA_PHOTOS_ADDED(count, added.title));
}

function rememberFiles(sent: AylaAttachment[]) {
  const files = sent.map(fileOfAttachment).filter((file): file is File => file !== null);
  rememberChatFiles(conversationId.value, files);
}

function clearItemContext() {
  conversation.clearItemContext();
  composerRef.value?.focus();
}

function openFilePicker() {
  composerRef.value?.openFilePicker();
}

watch(conversationId, (id, previousId) => {
  // What was added is kept with the chat it was said in (by its id); another chat shows nothing of it.
  if (previousId !== null || id === null) missingLook.value = null;
  // A new chat starts without files and without anything added.
  if (id === null) lastAdded.value = null;
  if (id === null) forgetNewChatFiles();
  // Moving from the home screen to the new chat keeps what is being typed.
  if (previousId === null && id && text.value) return;
  text.value = readDraft(id);
});
watch(text, (value) => saveDraft(conversationId.value, value));
// "Nieuwe chat": the cursor goes into the chatbox, ready for the first question.
watch(conversation.newChatCount, async () => {
  await nextTick();
  composerRef.value?.focus();
});
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

// Leaving the home screen for another page drops the choice; arriving from a chat on the way to it keeps it.
// useRoute() is still the route of the page that is closing; the router knows where we are going.
onBeforeUnmount(() => {
  if (router.currentRoute.value.path !== '/') {
    projects.state.value.newChatProjectId = null;
    lock.state.value.isNewChatLocked = false;
  }
});

defineExpose({ openFilePicker });
</script>

<template>
  <div class="relative flex min-h-0 flex-1 flex-col" :style="isFloating ? { '--ayla-float-height': `${floatHeight + 24}px` } : undefined">
    <!-- On a screen such as the vault the screen stays; the conversation shows in the chat list and above the chatbox. -->
    <AylaCanvas
      v-if="!screen && (hasMessages || isReadingFiles)"
      :latest-answer="latestAnswer"
      :is-writing="state.isWriting"
      :is-reading-files="isReadingFiles"
      :conversation-id="conversationId"
    />
    <slot v-else name="empty" />

    <!-- Over a screen such as the vault, the chatbox floats: what is behind it stays visible around it. -->
    <div
      ref="floating"
      :class="
        isFloating
          ? [
              'pointer-events-none absolute inset-x-0 bottom-0 *:pointer-events-auto',
              // Over the vault, Ayla's answer and the chatbox get a white fade behind them, so the cards never show through.
              hasMessages || isSavingToVault ? 'bg-linear-to-t from-white from-75% to-transparent pt-12' : '',
            ]
          : 'relative'
      "
      class="flex flex-col items-center px-4 pb-4"
    >
      <!-- Only while talking is on: Ayla's small orb, above her answer and the text field. -->
      <AylaVoiceDock v-if="voice.isActive.value" class="relative mb-3" />
      <!-- While Ayla saves, above her message, where the chat goes on. -->
      <AylaPixelLoader v-if="isSavingToVault" class="relative mb-4" mode="thinking" :label="AYLA_VAULT_SAVING" />
      <AylaLatestBubble
        v-if="latestAnswer?.text && !(missingLook && lastAdded)"
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
      <AylaNotice v-if="followUpProblem" class="relative mb-3 w-full max-w-147.75" :message="followUpProblem" />
      <AylaNotice v-if="voice.session.value.problem" class="relative mb-3 w-full max-w-147.75" :message="voice.session.value.problem" />
      <AylaNotice
        v-if="conversation.redoError.value"
        class="relative mb-3 w-full max-w-147.75"
        :message="conversation.redoError.value"
      />

      <AylaContextChip
        v-if="newChatProject"
        class="relative mb-2.5"
        :title="newChatProject.name"
        :label="getProjectChipLabel(newChatProject.name)"
        icon="folder"
        @clear="projects.state.value.newChatProjectId = null"
      />
      <AylaContextChip
        v-else-if="isNewChatLocked"
        class="relative mb-2.5"
        :title="AYLA_LOCKED_CHATS"
        :label="AYLA_LOCKED_CHIP"
        icon="lock"
        @clear="lock.state.value.isNewChatLocked = false"
      />
      <AylaContextChip
        v-if="itemContext"
        class="relative mb-2.5"
        :title="itemContext.title"
        :label="itemContext.itemIds ? itemContext.title : undefined"
        @clear="clearItemContext"
      />
      <AylaChoiceBar
        v-if="trayQuestion && !voice.isActive.value"
        class="relative"
        :question="trayQuestion.text"
        :choices="trayQuestion.choices"
        :caption="trayQuestion.caption"
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
        @send="voice.isActive.value ? sendWhileTalking() : sendTyped(text, $event)"
        @stop="conversation.stop"
        @talk="voice.start"
        @mute="voice.toggleMute"
        @stop-talking="voice.stop"
        @reading-files="isComposerReading = $event"
        @pick-item="pickerRef?.open()"
      />
      <p class="relative mt-2 text-center text-xs text-muted">{{ AYLA_DISCLAIMER }}</p>
    </div>

    <input
      ref="followUpPhotos"
      type="file"
      multiple
      accept="image/*"
      class="sr-only"
      tabindex="-1"
      aria-hidden="true"
      @change="addFollowUpPhotos"
    />
    <input
      ref="lookPicker"
      type="file"
      :accept="VAULT_COVER_ACCEPT"
      class="sr-only"
      tabindex="-1"
      aria-hidden="true"
      @change="addLook"
    />
    <VaultRequestDialog :item-id="confirmItemId" @close="confirmItemId = null" />
    <AylaVaultPicker ref="picker" @pick="conversation.attachItems($event); composerRef?.focus()" />

    <!-- Announces Ayla's answer once it is complete, not every word while she writes. -->
    <p class="sr-only" aria-live="polite">{{ state.announcement }}</p>
  </div>
</template>
