import type { VaultSkillsMaterial } from '~/utils/vaultSkillsMaterial';
import type {
  VaultFile,
  VaultFileRole,
  VaultFolder,
  VaultFolderColor,
  VaultFolderIcon,
  VaultItem,
  VaultItemDraft,
  VaultShelf,
  VaultSkillSuggestion,
} from '~/types/vault';

const BUCKET = 'pave-vault';
// A link to a logo or cover lasts an hour; the vault is read again after every change and on every visit.
const IMAGE_LINK_SECONDS = 60 * 60;
// The example folders were made from this browser once; deleting one later must not bring it back (as on iOS).
const EXAMPLE_FOLDERS_KEY = 'pave-vault-example-folders-made';
const ITEM_SELECT = '*,vault_item_skills(name,status),vault_item_files(*)';

export type VaultLoadStatus = 'loading' | 'ready' | 'failed';

interface VaultState {
  status: VaultLoadStatus;
  loadError: string | null;
  items: VaultItem[];
  folders: VaultFolder[];
  // Saving, moving or deleting did not work; the page shows it.
  problem: string | null;
}

interface ItemRow {
  id: string;
  folder_id: string | null;
  category: string;
  title: string;
  description: string | null;
  organisation_name: string | null;
  organisation_location: string | null;
  start_date: string | null;
  end_date: string | null;
  issued_on: string | null;
  is_current: boolean;
  verification_status: string;
  source: string;
  // Added by later migrations; missing on a database without them.
  organization_id?: string | null;
  ayla_allowed_at?: string | null;
  created_at: string;
  updated_at: string;
  vault_item_skills: { name: string; status: string }[] | null;
  vault_item_files: { id: string; file_name: string; mime_type: string; storage_path: string; role?: string | null }[] | null;
  vault_item_folders?: { folder_id: string }[] | null;
}

interface FolderRow {
  id: string;
  name: string;
  color: string | null;
  icon: string | null;
  created_at: string;
}

interface ErrorLike {
  code?: string;
  message?: string;
  status?: number;
}

/** Null for a category or status this version of the app does not know yet, as on iOS. */
function toItem(row: ItemRow): VaultItem | null {
  if (!(VAULT_CATEGORIES as string[]).includes(row.category)) return null;
  if (!(VAULT_STATUSES as string[]).includes(row.verification_status)) return null;
  const files: VaultFile[] = (row.vault_item_files ?? []).map((file) => ({
    id: file.id,
    name: file.file_name,
    mimeType: file.mime_type,
    storagePath: file.storage_path,
    role: fileRole(file.role, file.storage_path),
  }));
  // folder_id first (what older clients set), then every linked folder once.
  const folderIds = row.folder_id ? [row.folder_id] : [];
  for (const link of row.vault_item_folders ?? []) if (!folderIds.includes(link.folder_id)) folderIds.push(link.folder_id);
  return {
    id: row.id,
    folderIds,
    category: row.category as VaultItem['category'],
    title: row.title,
    description: row.description,
    organisationName: row.organisation_name,
    organisationLocation: row.organisation_location,
    startDate: row.start_date,
    endDate: row.end_date,
    issuedOn: row.issued_on,
    isCurrent: row.is_current,
    status: row.verification_status as VaultItem['status'],
    source: (['user', 'organization', 'ayla', 'import'].includes(row.source) ? row.source : 'user') as VaultItem['source'],
    logoUrl: null,
    coverUrl: null,
    aylaAllowedAt: row.ayla_allowed_at ?? null,
    skills: (row.vault_item_skills ?? [])
      .filter((skill) => skill.status === 'accepted')
      .map((skill) => skill.name)
      .sort((a, b) => a.localeCompare(b, 'nl')),
    files,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function toFolder(row: FolderRow): VaultFolder {
  return {
    id: row.id,
    name: row.name,
    color: row.color && row.color in VAULT_FOLDER_COLORS ? (row.color as VaultFolderColor) : null,
    icon: row.icon && row.icon in VAULT_FOLDER_ICONS ? (row.icon as VaultFolderIcon) : null,
    createdAt: row.created_at,
  };
}

function messageFor(error: ErrorLike | null) {
  if (error?.code === '23505') return VAULT_FOLDER_NAME_TAKEN;
  if (error?.code === 'PGRST301' || error?.status === 401) return VAULT_ERROR_NOT_SIGNED_IN;
  if (error?.code === '42501' || error?.status === 403) return VAULT_ERROR_NOT_ALLOWED;
  if (isNotThereYet(error)) return VAULT_ERROR_NOT_READY;
  if (error?.message?.toLowerCase().includes('fetch')) return VAULT_ERROR_NO_CONNECTION;
  return VAULT_ERROR_GENERIC;
}

/** A thrown error with the message to show, so the steps of a save can stop at the first failure. */
export class VaultSaveError extends Error {}

/**
 * Your vault, read from and written to the same Supabase tables as the iPhone (docs/vault.md, iOS SupabaseVaultService).
 * Row-level security keeps it to your own rows; after every change the vault is read again, so counts and folders match
 * the server. Every step works before the newest migrations too, the way iOS does.
 */
export function useVault() {
  const supabase = useUntypedSupabase();
  const supabaseConfig = useRuntimeConfig().public.supabase;
  const state = useState<VaultState>('vault', () => ({
    status: 'loading',
    loadError: null,
    items: [],
    folders: [],
    problem: null,
  }));
  const shelves = computed(() => buildShelves(state.value.items, state.value.folders));

  /** The items with their folder links; before migration 20261112130000 folder_id is the only folder. */
  async function readItems() {
    const withFolders = await supabase
      .from('vault_items')
      .select(`${ITEM_SELECT},vault_item_folders(folder_id)`)
      .order('updated_at', { ascending: false });
    if (!isNotThereYet(withFolders.error)) return withFolders;
    return supabase.from('vault_items').select(ITEM_SELECT).order('updated_at', { ascending: false });
  }

  /** Shows the loading shapes only the first time; after that the vault stays while it refreshes. */
  async function load() {
    const [items, folders] = await Promise.all([
      readItems(),
      supabase.from('vault_folders').select('*').order('created_at', { ascending: true }),
    ]);
    const error = items.error ?? folders.error;
    if (error) {
      if (state.value.status !== 'ready') {
        state.value.status = 'failed';
        state.value.loadError = messageFor(error);
      }
      return;
    }
    const rows = items.data as ItemRow[];
    const loaded = rows.map((row) => ({ row, item: toItem(row) })).filter((entry) => entry.item !== null);
    const [logos, images] = await Promise.all([loadLogos(rows), loadImages(loaded.map((entry) => entry.item!))]);
    state.value.items = loaded.map(({ row, item }) => ({
      ...item!,
      logoUrl:
        (row.organization_id ? logos.get(row.organization_id) : undefined) ??
        images.get(`logo:${item!.id}`) ??
        images.get(`cover:${item!.id}`) ??
        null,
      coverUrl: images.get(`cover:${item!.id}`) ?? null,
    }));
    state.value.folders = (folders.data as FolderRow[]).map(toFolder);
    state.value.status = 'ready';
    await makeExampleFoldersIfNeeded();
  }

  /**
   * Until migration 20261112120000 makes them on the server: an account without any folder gets the four example
   * folders once, and its items go into the folder of their kind, as they showed before (iOS does the same).
   */
  async function makeExampleFoldersIfNeeded() {
    if (state.value.folders.length || readFlag(EXAMPLE_FOLDERS_KEY)) return;
    writeFlag(EXAMPLE_FOLDERS_KEY);
    const made: VaultFolder[] = [];
    for (const example of EXAMPLE_FOLDERS) {
      const { data } = await supabase
        .from('vault_folders')
        .insert({ name: example.name, color: example.color, icon: example.icon })
        .select()
        .single();
      if (data) made.push(toFolder(data as FolderRow));
    }
    if (!made.length) return;
    for (const item of state.value.items) {
      if (item.folderIds.length) continue;
      const folder = kindFolder(item.category, made);
      if (folder) await writeFolders(item.id, [folder.id]);
    }
    await load();
  }

  /** The logos of the organisations behind the items. Without them the cards show a letter, so a failure is ignored. */
  async function loadLogos(rows: ItemRow[]) {
    const logos = new Map<string, string>();
    const ids = [...new Set(rows.map((row) => row.organization_id).filter((id): id is string => Boolean(id)))];
    if (!ids.length) return logos;
    const { data } = await supabase.from('organizations').select('id,logo_url').in('id', ids);
    for (const row of (data ?? []) as { id: string; logo_url: string | null }[]) {
      if (row.logo_url?.startsWith('https://')) logos.set(row.id, row.logo_url);
    }
    return logos;
  }

  /** Links to the logo and cover you added. Without a link the card shows its letter and colour, so a failure is ignored. */
  async function loadImages(items: VaultItem[]) {
    const wanted: { key: string; path: string }[] = [];
    for (const item of items) {
      for (const role of ['logo', 'cover'] as const) {
        const file = item.files.find((entry) => entry.role === role && SHOWN_IMAGE_TYPES.includes(entry.mimeType));
        if (file) wanted.push({ key: `${role}:${item.id}`, path: file.storagePath });
      }
    }
    const links = new Map<string, string>();
    if (!wanted.length) return links;
    const { data } = await supabase.storage.from(BUCKET).createSignedUrls(
      wanted.map((entry) => entry.path),
      IMAGE_LINK_SECONDS,
    );
    for (const link of data ?? []) {
      const entry = wanted.find((candidate) => candidate.path === link.path);
      if (entry && link.signedUrl) links.set(entry.key, link.signedUrl);
    }
    return links;
  }

  async function retry() {
    state.value.status = 'loading';
    await load();
  }

  function count(shelf: VaultShelf) {
    return state.value.items.filter((item) => isOnShelf(item, shelf)).length;
  }

  function folder(id: string | null) {
    return state.value.folders.find((item) => item.id === id) ?? null;
  }

  function isFolderNameTaken(name: string, exceptId?: string) {
    const wanted = name.trim().toLocaleLowerCase('nl');
    return state.value.folders.some((item) => item.id !== exceptId && item.name.trim().toLocaleLowerCase('nl') === wanted);
  }

  /** Runs a change and then reads the vault again. Returns whether it worked; otherwise `problem` says why. */
  async function perform(change: () => PromiseLike<{ error: ErrorLike | null }>) {
    const { error } = await change();
    if (error) {
      state.value.problem = messageFor(error);
      return false;
    }
    await load();
    return true;
  }

  // Steps that throw a VaultSaveError, for the forms: they show the reason themselves.

  async function userId() {
    const { data } = await supabase.auth.getSession();
    const id = data.session?.user.id;
    if (!id) throw new VaultSaveError(VAULT_ERROR_NOT_SIGNED_IN);
    return id;
  }

  function fail(error: ErrorLike | null): never {
    throw new VaultSaveError(messageFor(error));
  }

  /**
   * Puts the item in exactly these folders: folder_id holds the first for older clients, vault_item_folders all of
   * them. Before migration 20261112130000 there is no link table and folder_id is all there is.
   */
  async function writeFolders(itemId: string, folderIds: string[]) {
    const { error } = await supabase.from('vault_items').update({ folder_id: folderIds[0] ?? null }).eq('id', itemId);
    if (error) fail(error);
    const removed = await supabase.from('vault_item_folders').delete().eq('item_id', itemId);
    if (isNotThereYet(removed.error)) return;
    if (removed.error) fail(removed.error);
    const rows = [...new Set(folderIds)].map((folderId) => ({ item_id: itemId, folder_id: folderId }));
    if (!rows.length) return;
    const linked = await supabase.from('vault_item_folders').upsert(rows, { ignoreDuplicates: true });
    if (linked.error && !isNotThereYet(linked.error)) fail(linked.error);
  }

  /** A new item, always your own and not confirmed; returns its id. */
  async function addItem(draft: VaultItemDraft, folderIds: string[]) {
    const { data, error } = await supabase
      .from('vault_items')
      .insert({ ...toVaultItemRow(draft), folder_id: folderIds[0] ?? null })
      .select('id')
      .single();
    if (error || !data) fail(error);
    const id = (data as { id: string }).id;
    // The item exists and folder_id holds its first folder; extra folder links must never undo that (as on iOS).
    try {
      await writeFolders(id, folderIds);
    } catch {
      // The item is saved in its first folder.
    }
    return id;
  }

  /** The details and folders of an item. Changing a confirmed one sets it back to "Niet bevestigd" (the database does). */
  async function saveDetails(itemId: string, draft: VaultItemDraft, folderIds: string[]) {
    const { error } = await supabase
      .from('vault_items')
      .update({ ...toVaultItemRow(draft), folder_id: folderIds[0] ?? null })
      .eq('id', itemId);
    if (error) fail(error);
    await writeFolders(itemId, folderIds);
  }

  /**
   * Uploads a file to the private bucket and records it with its role. Without the role column (before migration
   * 20261112120000) a document is recorded without it; a logo or cover keeps its "logo-"/"cover-" name so this app
   * still knows it. The object is removed again when its row cannot be written.
   */
  async function attach(itemId: string, file: File, role: VaultFileRole) {
    const mimeType = getVaultMimeType(file);
    if (!mimeType || (role !== 'document' && !mimeType.startsWith('image/'))) throw new VaultSaveError(VAULT_COVER_TYPE);
    const owner = await userId();
    const prefix = role === 'document' ? '' : VAULT_FILE_PREFIXES[role];
    const path = `${owner}/${itemId}/${prefix}${crypto.randomUUID()}.${getExtension(file.name)}`;
    const upload = await supabase.storage.from(BUCKET).upload(path, file, { contentType: mimeType, upsert: false });
    if (upload.error) fail(upload.error);
    const row = {
      item_id: itemId,
      storage_path: path,
      file_name: file.name.slice(0, 255),
      mime_type: mimeType,
      file_size_bytes: file.size,
    };
    let record = await supabase.from('vault_item_files').insert({ ...row, role });
    if (isNotThereYet(record.error)) record = await supabase.from('vault_item_files').insert(row);
    if (record.error) {
      await supabase.storage.from(BUCKET).remove([path]);
      fail(record.error);
    }
  }

  /** One file of an item: first from Storage, then its row. */
  async function removeFile(file: VaultFile) {
    const removed = await supabase.storage.from(BUCKET).remove([file.storagePath]);
    if (removed.error) fail(removed.error);
    const { error } = await supabase.from('vault_item_files').delete().eq('id', file.id);
    if (error) fail(error);
  }

  /** Skills you add yourself are accepted straight away; names already on the item are skipped. */
  async function addSkills(itemId: string, names: string[]) {
    const rows = names.map((name) => ({ item_id: itemId, name: name.trim() })).filter((row) => row.name);
    if (!rows.length) return;
    const { error } = await supabase.from('vault_item_skills').upsert(rows, { ignoreDuplicates: true });
    if (error && error.code !== '23505') fail(error);
  }

  async function removeSkills(itemId: string, names: string[]) {
    if (!names.length) return;
    const { error } = await supabase.from('vault_item_skills').delete().eq('item_id', itemId).in('name', names);
    if (error) fail(error);
  }

  /** "Ayla mag dit bekijken en gebruiken": the standing yes for one item, which you can take back. */
  async function setAylaAllowed(itemId: string, isAllowed: boolean) {
    const { error } = await supabase
      .from('vault_items')
      .update({ ayla_allowed_at: isAllowed ? new Date().toISOString() : null })
      .eq('id', itemId);
    if (error) fail(error);
  }

  /**
   * "Voorstel van Ayla": skills that fit the evidence. The form and what could be read from the files go to Ayla, only
   * on request. Called the way the chat calls Ayla (a plain request with the session's token), and like iOS it waits
   * longer when photos are sent along and says why it failed: not signed in, no two-step verification, no connection.
   */
  async function suggestSkills(
    draft: VaultItemDraft,
    existing: string[],
    material: VaultSkillsMaterial = { files: [], images: [] },
  ): Promise<VaultSkillSuggestion[]> {
    const { data: session } = await supabase.auth.getSession();
    const token = session.session?.access_token;
    if (!token) throw new VaultSaveError(VAULT_AYLA_SKILLS_SIGNED_OUT);

    const { url, key } = supabaseConfig;
    let response: Response;
    try {
      response = await fetch(`${url}/functions/v1/ayla-skills`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, apikey: key },
        body: JSON.stringify({
          category: draft.category || 'other',
          title: draft.title.trim(),
          organisation: draft.organisationName.trim(),
          description: draft.description.trim(),
          existing,
          files: material.files,
          images: material.images,
        }),
        signal: AbortSignal.timeout(material.images.length ? 60_000 : 40_000),
      });
    } catch (error) {
      if (import.meta.dev) console.error('ayla-skills: no answer', error);
      throw new VaultSaveError(VAULT_AYLA_SKILLS_NO_CONNECTION);
    }
    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      if (import.meta.dev) console.error(`ayla-skills: ${response.status}`, detail);
      const message =
        response.status === 404
          ? VAULT_AYLA_SKILLS_NOT_READY
          : response.status === 401
            ? VAULT_AYLA_SKILLS_SIGNED_OUT
            : response.status === 403
              ? INSUFFICIENT_AAL_MESSAGE
              : VAULT_AYLA_SKILLS_FAILED;
      // In development the technical reason goes under the message (as in a debug build on iOS).
      throw new VaultSaveError(import.meta.dev ? `${message} [${response.status} ${detail.slice(0, 120)}]` : message);
    }
    const skills = ((await response.json().catch(() => null)) as { skills?: unknown } | null)?.skills;
    if (!Array.isArray(skills)) throw new VaultSaveError(VAULT_AYLA_SKILLS_FAILED);
    return skills
      .filter((entry): entry is VaultSkillSuggestion => typeof entry?.name === 'string')
      .map((entry) => ({ name: entry.name, reason: typeof entry.reason === 'string' ? entry.reason : '' }));
  }

  /** Puts the item in this folder as well, or takes it out of it; its other folders stay. */
  async function toggleFolder(item: VaultItem, folderId: string) {
    const folderIds = item.folderIds.includes(folderId)
      ? item.folderIds.filter((id) => id !== folderId)
      : [...item.folderIds, folderId];
    return setFolders(item, folderIds);
  }

  async function setFolders(item: VaultItem, folderIds: string[]) {
    try {
      await writeFolders(item.id, folderIds);
    } catch (error) {
      state.value.problem = error instanceof VaultSaveError ? error.message : VAULT_ERROR_GENERIC;
      return false;
    }
    await load();
    return true;
  }

  /** The files go first: the database cannot remove them from Storage itself. */
  async function remove(item: VaultItem) {
    if (item.files.length) {
      const { error } = await supabase.storage.from(BUCKET).remove(item.files.map((file) => file.storagePath));
      if (error) {
        state.value.problem = messageFor(error);
        return false;
      }
    }
    return perform(() => supabase.from('vault_items').delete().eq('id', item.id));
  }

  async function createFolder(name: string, color: VaultFolderColor, icon: VaultFolderIcon) {
    const { data, error } = await supabase.from('vault_folders').insert({ name: name.trim(), color, icon }).select().single();
    if (error || !data) {
      state.value.problem = messageFor(error);
      return null;
    }
    const created = toFolder(data as FolderRow);
    state.value.folders = [...state.value.folders, created];
    return created;
  }

  function updateFolder(id: string, name: string, color: VaultFolderColor, icon: VaultFolderIcon) {
    return perform(() => supabase.from('vault_folders').update({ name: name.trim(), color, icon }).eq('id', id));
  }

  /** The items in the folder stay in the vault. */
  function deleteFolder(id: string) {
    return perform(() => supabase.from('vault_folders').delete().eq('id', id));
  }

  return {
    state,
    shelves,
    load,
    retry,
    count,
    folder,
    isFolderNameTaken,
    addItem,
    saveDetails,
    saveFolders: writeFolders,
    attach,
    removeFile,
    addSkills,
    removeSkills,
    setAylaAllowed,
    suggestSkills,
    toggleFolder,
    setFolders,
    remove,
    createFolder,
    updateFolder,
    deleteFolder,
  };
}

function readFlag(key: string) {
  try {
    return localStorage.getItem(key) === '1';
  } catch {
    return false;
  }
}

function writeFlag(key: string) {
  try {
    localStorage.setItem(key, '1');
  } catch {
    // Without storage it may be tried again next time; the names are unique, so nothing is made twice.
  }
}
