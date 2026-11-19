import type { Project } from '~/types/ayla';

export type ProjectsStatus = 'idle' | 'loading' | 'ready' | 'unavailable';

interface ProjectsState {
  projects: Project[];
  status: ProjectsStatus;
  canPin: boolean;
  // Which project a chat is in (chat id → project id). Chats in a project show under it, not under Recent.
  chatProjects: Record<string, string>;
  // "Nieuwe chat" on a project: the next chat that starts on the home screen goes into this project.
  newChatProjectId: string | null;
  // A short line under the Projecten list, such as "Chat verplaatst naar …".
  notice: { text: string; isError: boolean } | null;
  // Goes up when a chat moves into a project, so an open project page reloads its chats.
  chatsVersion: number;
}

interface ProjectRow {
  id: string;
  name: string;
  instructions: string;
  updated_at: string;
  pinned_at?: string | null;
}

const COLUMNS_WITH_PIN = 'id,name,instructions,updated_at,pinned_at';
const COLUMNS_WITHOUT_PIN = 'id,name,instructions,updated_at';
const LIST_LIMIT = 50;

function toProject(row: ProjectRow): Project {
  return {
    id: row.id,
    name: row.name,
    instructions: row.instructions,
    updatedAt: row.updated_at,
    pinnedAt: row.pinned_at ?? null,
  };
}

/** Pinned projects first (the latest pinned on top), then by when they were last changed. */
function sortForList(projects: Project[]) {
  return [...projects].sort((first, second) => {
    if (first.pinnedAt || second.pinnedAt) return (second.pinnedAt ?? '').localeCompare(first.pinnedAt ?? '');
    return second.updatedAt.localeCompare(first.updatedAt);
  });
}

let noticeTimer: ReturnType<typeof setTimeout> | undefined;
const NOTICE_MS = 3000;

/**
 * The user's projects: folders for chats with their own instructions for Ayla (migration 20261118120000).
 * Until that migration runs the table is missing: the status is then 'unavailable' and the screens hide projects,
 * so nothing else in the chat is affected.
 */
export function useAylaProjects() {
  const supabase = useUntypedSupabase();
  const state = useState<ProjectsState>('ayla-projects', () => ({ projects: [], status: 'idle', canPin: true, chatProjects: {}, newChatProjectId: null, notice: null, chatsVersion: 0 }));

  async function load() {
    if (state.value.status !== 'ready') state.value.status = 'loading';
    const select = (columns: string) =>
      supabase.from('ayla_projects').select(columns).order('updated_at', { ascending: false }).limit(LIST_LIMIT);
    let { data, error } = await select(COLUMNS_WITH_PIN);
    // Until the pinned_at migration runs, pinning is hidden and the list still loads.
    if (isMissingColumn(error)) {
      state.value.canPin = false;
      ({ data, error } = await select(COLUMNS_WITHOUT_PIN));
    }
    if (error || !data) {
      state.value.status = 'unavailable';
      return;
    }
    state.value.projects = sortForList((data as unknown as ProjectRow[]).map(toProject));
    state.value.status = 'ready';
  }

  /** Reads which chats are in a project. Without the column the answer is "none" and nothing changes. */
  async function loadMembership() {
    const { data, error } = await supabase.from('ayla_conversations').select('id,project_id').not('project_id', 'is', null);
    if (error || !data) return;
    const rows = data as unknown as { id: string; project_id: string }[];
    state.value.chatProjects = Object.fromEntries(rows.map((row) => [row.id, row.project_id]));
  }

  function setMembership(chatId: string, projectId: string | null) {
    const next = { ...state.value.chatProjects };
    if (projectId) next[chatId] = projectId;
    else delete next[chatId];
    state.value.chatProjects = next;
    state.value.chatsVersion += 1;
  }

  /** Opens an empty chat that belongs to the project, without a page of its own for the project. */
  async function startChatIn(projectId: string) {
    state.value.newChatProjectId = projectId;
    await navigateTo('/');
  }

  function showNotice(text: string, isError = false) {
    state.value.notice = { text, isError };
    clearTimeout(noticeTimer);
    noticeTimer = setTimeout(() => (state.value.notice = null), NOTICE_MS);
  }

  function find(id: string) {
    return state.value.projects.find((project) => project.id === id);
  }

  async function create(name: string) {
    const trimmedName = name.trim().replace(/\s+/g, ' ').slice(0, AYLA_MAX_TITLE_LENGTH);
    if (!trimmedName) return { project: null, isFailed: true };
    const { data, error } = await supabase.from('ayla_projects').insert({ name: trimmedName }).select(COLUMNS_WITHOUT_PIN).single();
    if (error || !data) return { project: null, isFailed: true };
    const project = toProject(data as unknown as ProjectRow);
    state.value.projects = sortForList([project, ...state.value.projects]);
    return { project, isFailed: false };
  }

  /** Changes the list first and puts it back when Supabase refuses: an empty result means a rule said no. */
  async function update(id: string, changes: Partial<Pick<Project, 'name' | 'instructions'>>) {
    const previous = find(id);
    if (!previous) return { isFailed: true };
    const next = {
      ...changes,
      ...(changes.name === undefined ? {} : { name: changes.name.trim().replace(/\s+/g, ' ').slice(0, AYLA_MAX_TITLE_LENGTH) }),
    };
    if (next.name === '') return { isFailed: true };

    replace(id, next);
    const { data, error } = await supabase
      .from('ayla_projects')
      .update({ ...next, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select('id');
    const isFailed = Boolean(error) || !data?.length;
    if (isFailed) replace(id, previous);
    return { isFailed };
  }

  function replace(id: string, changes: Partial<Project>) {
    state.value.projects = sortForList(
      state.value.projects.map((project) => (project.id === id ? { ...project, ...changes } : project)),
    );
  }

  async function setPinned(id: string, isPinned: boolean) {
    const previous = find(id);
    if (!previous) return { isFailed: true };
    const pinnedAt = isPinned ? new Date().toISOString() : null;
    replace(id, { pinnedAt });
    const { data, error } = await supabase.from('ayla_projects').update({ pinned_at: pinnedAt }).eq('id', id).select('id');
    const isFailed = Boolean(error) || !data?.length;
    if (isFailed) replace(id, previous);
    return { isFailed };
  }

  /** The chats of the project go back to the normal list: the database only forgets which project they were in. */
  async function remove(id: string) {
    const { data, error } = await supabase.from('ayla_projects').delete().eq('id', id).select('id');
    const isFailed = Boolean(error) || !data?.length;
    if (!isFailed) state.value.projects = state.value.projects.filter((project) => project.id !== id);
      state.value.chatProjects = Object.fromEntries(Object.entries(state.value.chatProjects).filter(([, projectId]) => projectId !== id));
    return { isFailed };
  }

  /** Puts a chat in a project (or back in the normal list with null). */
  async function moveChat(conversationId: string, projectId: string | null) {
    const { data, error } = await supabase
      .from('ayla_conversations')
      .update({ project_id: projectId })
      .eq('id', conversationId)
      .select('id');
    const isFailed = Boolean(error) || !data?.length;
    if (!isFailed) setMembership(conversationId, projectId);
    return { isFailed };
  }

  return { state, load, find, create, update, remove, setPinned, loadMembership, setMembership, showNotice, moveChat, startChatIn };
}
