import type { AylaAttachment, AylaErrorCode, AylaInput, ChatMessage, AylaScreen } from '~/types/ayla';

export type ConversationLoadStatus = 'idle' | 'loading' | 'ready' | 'notFound' | 'failed';

interface ConversationState {
  conversationId: string | null;
  messages: ChatMessage[];
  loadStatus: ConversationLoadStatus;
  isWriting: boolean;
  error: AylaErrorCode | null;
  announcement: string;
}

/** The vault item a new chat is about ("Vraag Ayla over dit bewijs"): every question then goes with it. */
export interface AylaItemContext {
  itemId: string;
  title: string;
}

export interface SendOptions {
  text: string;
  attachments?: AylaAttachment[];
  input?: AylaInput;
  // What the user has open, such as the vault, so Ayla knows where the question comes from.
  context?: { screen: AylaScreen; itemId?: string };
  onConversationStarted?: (conversationId: string) => void;
}

/** What to put back in the composer when a question could not be sent. */
export interface SendResult {
  failedText: string | null;
  failedAttachments: AylaAttachment[];
}

// Lives outside the state: an AbortController cannot be serialised, and sending only happens in the browser.
let stopController: AbortController | null = null;

function createEmptyState(): ConversationState {
  return {
    conversationId: null,
    messages: [],
    loadStatus: 'idle',
    isWriting: false,
    error: null,
    announcement: '',
  };
}

/**
 * The open conversation, shared between the home screen and the chat screen, so a question asked on the home
 * screen keeps streaming while the app moves to /ayla/<id>.
 */
export function useAylaConversation() {
  const state = useState<ConversationState>('ayla-conversation', createEmptyState);
  // A question taken back with "Aanpassen", waiting for the composer to pick it up.
  const questionToEdit = useState<string | null>('ayla-question-to-edit', () => null);
  const redoError = useState<string | null>('ayla-redo-error', () => null);
  const itemContext = useState<AylaItemContext | null>('ayla-item-context', () => null);
  // Set just before the new chat opens, which then takes it over; any other new chat starts without one.
  const nextItemContext = useState<AylaItemContext | null>('ayla-next-item-context', () => null);
  const { streamQuestion, loadMessages, removeLastTurn } = useAyla();

  function stop() {
    stopController?.abort();
  }

  function startNew() {
    stop();
    state.value = { ...createEmptyState(), loadStatus: 'ready' };
    itemContext.value = nextItemContext.value;
    nextItemContext.value = null;
  }

  /** Starts a new chat about one vault item. */
  function askAboutItem(context: AylaItemContext) {
    nextItemContext.value = context;
    return navigateTo('/');
  }

  function clearItemContext() {
    itemContext.value = null;
  }

  function getRequestContext(options: SendOptions) {
    if (itemContext.value) return { screen: 'vaultItem' as const, itemId: itemContext.value.itemId };
    return options.context;
  }

  async function open(conversationId: string) {
    const isAlreadyOpen = state.value.conversationId === conversationId && state.value.loadStatus === 'ready';
    if (isAlreadyOpen) return;

    stop();
    // The item belongs to the chat it was asked in, not to another chat opened from the list.
    clearItemContext();
    state.value = { ...createEmptyState(), conversationId, loadStatus: 'loading' };
    const { data, isNotFound } = await loadMessages(conversationId);
    if (state.value.conversationId !== conversationId) return;

    if (isNotFound) state.value.loadStatus = 'notFound';
    else if (!data) state.value.loadStatus = 'failed';
    else {
      state.value.messages = data;
      state.value.loadStatus = 'ready';
    }
  }

  function removeMessages(ids: string[]) {
    state.value.messages = state.value.messages.filter((message) => !ids.includes(message.id));
  }

  function addTurn(text: string, attachments: AylaAttachment[]) {
    const question = createMessage('user', text);
    question.attachmentNames = attachments.map((attachment) => attachment.name);
    const answer = { ...createMessage('ayla', ''), isWriting: true };
    state.value.messages.push(question, answer);

    // Read the answer back from the state, so changes to it are reactive.
    const reactiveAnswer = state.value.messages[state.value.messages.length - 1] as ChatMessage;
    return { questionId: question.id, answer: reactiveAnswer };
  }

  async function send(options: SendOptions): Promise<SendResult> {
    const text = options.text.trim();
    const attachments = options.attachments ?? [];
    const nothingFailed = { failedText: null, failedAttachments: [] };
    if (!text || state.value.isWriting) return nothingFailed;

    state.value.error = null;
    state.value.isWriting = true;
    stopController = new AbortController();
    const { questionId, answer } = addTurn(text, attachments);
    const context = getRequestContext(options);

    const result = await streamQuestion(
      {
        text,
        device: 'web',
        input: options.input ?? 'text',
        ...(state.value.conversationId ? { conversationId: state.value.conversationId } : {}),
        ...(attachments.length ? { attachments } : {}),
        ...(context ? { context } : {}),
      },
      {
        onStart(conversationId) {
          if (state.value.conversationId) return;
          state.value.conversationId = conversationId;
          state.value.loadStatus = 'ready';
          options.onConversationStarted?.(conversationId);
        },
        onText(writtenText) {
          answer.text = writtenText;
        },
        onReply(reply) {
          answer.text = reply.text;
          answer.reply = reply;
          answer.isWriting = false;
          state.value.announcement = `${AYLA_NAME}: ${reply.text}`;
        },
      },
      stopController.signal,
    );

    state.value.isWriting = false;
    stopController = null;
    answer.isWriting = false;

    // Stopped after Ayla wrote something: the server keeps it as her answer, so it stays on screen.
    const keepsAnswer = result.isStopped && answer.text.length > 0;
    if (!result.error && (keepsAnswer || !result.isStopped)) return nothingFailed;

    // Nothing was saved on the server: take the turn away and give the question back.
    removeMessages([questionId, answer.id]);
    if (result.error === 'conversation_not_found') state.value.loadStatus = 'notFound';
    state.value.error = result.error;
    return { failedText: text, failedAttachments: attachments };
  }

  /** "Nieuw antwoord" (asks the last question again) or "Aanpassen" (puts it back in the composer). */
  async function changeLastTurn(mode: 'answerAgain' | 'editQuestion') {
    const conversationId = state.value.conversationId;
    redoError.value = null;
    if (!conversationId || state.value.isWriting) return;

    const { question } = await removeLastTurn(conversationId);
    if (question === null) {
      redoError.value = AYLA_REDO_FAILED;
      return;
    }
    state.value.messages = state.value.messages.slice(0, -2);
    if (mode === 'editQuestion') questionToEdit.value = question;
    else await send({ text: question });
  }

  return {
    state,
    questionToEdit,
    redoError,
    itemContext,
    open,
    startNew,
    askAboutItem,
    clearItemContext,
    send,
    stop,
    changeLastTurn,
  };
}
