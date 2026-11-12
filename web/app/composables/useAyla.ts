import type {
  AylaErrorCode,
  AylaReply,
  AylaRequest,
  ChatMessage,
} from '~/types/ayla';

interface StreamHandlers {
  onStart: (conversationId: string) => void;
  onText: (text: string) => void;
  onReply: (reply: AylaReply) => void;
}

interface StreamResult {
  error: AylaErrorCode | null;
  isStopped: boolean;
}

interface MessageRow {
  id: string;
  role: ChatMessage['role'];
  text: string;
  reply: unknown;
  created_at: string;
}

const AYLA_FUNCTION_PATH = '/functions/v1/ayla';
const AYLA_VOICE_PATH = '/functions/v1/ayla-voice';
const KNOWN_ERRORS: AylaErrorCode[] = [
  'invalid_request',
  'not_signed_in',
  'insufficient_aal',
  'conversation_not_found',
  'unavailable',
];
const ERROR_BY_STATUS: Record<number, AylaErrorCode> = {
  400: 'invalid_request',
  401: 'not_signed_in',
  403: 'insufficient_aal',
  404: 'conversation_not_found',
};
const LAST_TURN_SIZE = 2;

function isStopError(error: unknown) {
  return error instanceof DOMException && error.name === 'AbortError';
}

async function readErrorCode(response: Response): Promise<AylaErrorCode> {
  const body: unknown = await response.json().catch(() => null);
  const code = (body as { error?: string } | null)?.error;
  const knownCode = KNOWN_ERRORS.find((known) => known === code);
  return knownCode ?? ERROR_BY_STATUS[response.status] ?? 'unavailable';
}

function toChatMessage(row: MessageRow): ChatMessage {
  return {
    id: row.id,
    role: row.role,
    text: row.text,
    reply: row.role === 'ayla' ? parseReply(row.reply) : null,
    createdAt: row.created_at,
    isWriting: false,
    attachmentNames: [],
  };
}

export function useAyla() {
  const supabase = useUntypedSupabase();
  const { url: supabaseUrl, key: publishableKey } = useRuntimeConfig().public.supabase;

  async function getAccessToken() {
    const { data } = await supabase.auth.getSession();
    return data.session?.access_token ?? null;
  }

  async function postQuestion(request: AylaRequest, signal: AbortSignal) {
    const accessToken = await getAccessToken();
    if (!accessToken) return null;

    return fetch(`${supabaseUrl}${AYLA_FUNCTION_PATH}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
        Authorization: `Bearer ${accessToken}`,
        apikey: publishableKey,
      },
      body: JSON.stringify(request),
      signal,
    });
  }

  function handleEvent(name: string, data: unknown, handlers: StreamHandlers) {
    const values = (data ?? {}) as { conversationId?: string; text?: string };
    if (name === 'start' && values.conversationId) handlers.onStart(values.conversationId);
    if (name === 'text' && typeof values.text === 'string') handlers.onText(values.text);
    if (name !== 'reply') return false;

    const reply = parseReply(data);
    if (reply) handlers.onReply(reply);
    return Boolean(reply);
  }

  async function readStream(response: Response, handlers: StreamHandlers): Promise<StreamResult> {
    if (!response.body) return { error: 'unavailable', isStopped: false };

    const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
    let rest = '';
    let eventName = '';
    for (;;) {
      const { value, done } = await reader.read();
      if (done) return { error: 'unavailable', isStopped: false };

      const parsed = readStreamEvents(rest, value, eventName);
      rest = parsed.rest;
      eventName = parsed.name;
      for (const event of parsed.events) {
        if (event.name === 'error') return { error: 'unavailable', isStopped: false };
        if (handleEvent(event.name, event.data, handlers)) return { error: null, isStopped: false };
      }
    }
  }

  /** Sends a question and shows the answer while Ayla writes (docs/ayla.md, section 2). */
  async function streamQuestion(
    request: AylaRequest,
    handlers: StreamHandlers,
    signal: AbortSignal,
  ): Promise<StreamResult> {
    if (!navigator.onLine) return { error: 'offline', isStopped: false };
    try {
      const response = await postQuestion(request, signal);
      if (!response) return { error: 'not_signed_in', isStopped: false };
      if (!response.ok) return { error: await readErrorCode(response), isStopped: false };
      return await readStream(response, handlers);
    } catch (error) {
      if (isStopError(error)) return { error: null, isStopped: true };
      return { error: 'offline', isStopped: false };
    }
  }

  async function loadMessages(conversationId: string) {
    const [{ data: conversation, error: conversationError }, { data, error }] = await Promise.all([
      supabase.from('ayla_conversations').select('id').eq('id', conversationId).maybeSingle(),
      supabase
        .from('ayla_messages')
        .select('id,role,text,reply,created_at')
        .eq('conversation_id', conversationId)
        .order('created_at'),
    ]);
    if (conversationError || error) return { data: null, isNotFound: false };
    if (!conversation) return { data: null, isNotFound: true };

    const rows = (data ?? []) as MessageRow[];
    return { data: rows.map(toChatMessage), isNotFound: false };
  }

  /**
   * Removes the last question and Ayla's answer, so Ayla does not see the old answer when the question is asked
   * again (docs/ayla.md, section 4). Returns the question.
   */
  async function removeLastTurn(conversationId: string) {
    const { data, error } = await supabase
      .from('ayla_messages')
      .select('id,role,text')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: false })
      .limit(LAST_TURN_SIZE);
    if (error || !data) return { question: null };

    const [answer, question] = data as { id: string; role: string; text: string }[];
    if (answer?.role !== 'ayla' || question?.role !== 'user') return { question: null };

    const { data: deleted, error: deleteError } = await supabase
      .from('ayla_messages')
      .delete()
      .in('id', [answer.id, question.id])
      .select('id');
    if (deleteError || deleted?.length !== LAST_TURN_SIZE) return { question: null };
    return { question: question.text };
  }

  /** The first name (profile first, then the sign-in details) and a photo, if they exist. Nothing is created. */
  async function getAccount() {
    const { data: userData } = await supabase.auth.getUser();
    const user = userData.user;
    if (!user) return { firstName: null, fullName: null, avatarUrl: null };

    const { data: profile } = await supabase
      .from('profiles')
      .select('preferred_name, full_name')
      .eq('id', user.id)
      .maybeSingle();
    const names = profile as { preferred_name?: string | null; full_name?: string | null } | null;
    const metadata = user.user_metadata as Record<string, unknown>;
    const candidates = [
      names?.preferred_name,
      names?.full_name,
      metadata.first_name,
      metadata.full_name,
      metadata.name,
    ];
    const fullName = candidates.find((value) => typeof value === 'string' && value.trim());
    const name = typeof fullName === 'string' ? fullName.trim() : null;
    const firstName = name ? (name.split(' ')[0] ?? null) : null;
    const avatarUrl = typeof metadata.avatar_url === 'string' ? metadata.avatar_url : null;
    return { firstName, fullName: name, avatarUrl };
  }

  /**
   * Ayla's voice for one answer (docs/ayla.md, section 6): raw pcm16, 24 kHz, mono, streamed. Null when there is no
   * session or the voice is not available; the caller then uses the browser's own Dutch voice.
   */
  async function streamSpeech(text: string, signal: AbortSignal) {
    const accessToken = await getAccessToken();
    if (!accessToken) return null;
    try {
      const response = await fetch(`${supabaseUrl}${AYLA_VOICE_PATH}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
          apikey: publishableKey,
        },
        body: JSON.stringify({ text: text.slice(0, MAX_SPEECH_LENGTH) }),
        signal,
      });
      return response.ok && response.body ? response.body : null;
    } catch {
      return null;
    }
  }

  /** An OPTIONS request wakes both functions up, so the first spoken answer does not wait for a cold start. */
  function warmUp() {
    for (const path of [AYLA_FUNCTION_PATH, AYLA_VOICE_PATH]) {
      fetch(`${supabaseUrl}${path}`, { method: 'OPTIONS' }).catch(() => {});
    }
  }

  return { streamQuestion, loadMessages, removeLastTurn, getAccount, streamSpeech, warmUp };
}
