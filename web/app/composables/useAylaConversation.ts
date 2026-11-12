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

export interface SendOptions {
  text: string;
  attachments?: AylaAttachment[];
  input?: AylaInput;
  // What the user has open, such as the vault, so Ayla knows where the question comes from.
  context?: { screen: AylaScreen };
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
  const { streamQuestion, loadMessages, removeLastTurn } = useAyla();

  function stop() {
    stopController?.abort();
  }

  function startNew() {
    stop();
    state.value = { ...createEmptyState(), loadStatus: 'ready' };
  }

  async function open(conversationId: string) {
    const isAlreadyOpen = state.value.conversationId === conversationId && state.value.loadStatus === 'ready';
    if (isAlreadyOpen) return;

    stop();
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

    const result = await streamQuestion(
      {
        text,
        device: 'web',
        input: options.input ?? 'text',
        ...(state.value.conversationId ? { conversationId: state.value.conversationId } : {}),
        ...(attachments.length ? { attachments } : {}),
        ...(options.context ? { context: options.context } : {}),
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

  return { state, questionToEdit, redoError, open, startNew, send, stop, changeLastTurn };
}
