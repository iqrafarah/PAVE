import type {
  VaultCategoryFolder,
  VaultCategoryFolders,
  VaultFile,
  VaultFileRole,
  VaultFolder,
  VaultFolderColor,
  VaultFolderIcon,
  VaultItem,
  VaultItemCategory,
  VaultItemDraft,
  VaultShelf,
} from '~/types/vault';

const BUCKET = 'pave-vault';
// A link to a logo or cover lasts an hour; the vault is read again after every change and on every visit.
const IMAGE_LINK_SECONDS = 60 * 60;
const METADATA_KEY = 'vault_category_folders';

export type VaultLoadStatus = 'loading' | 'ready' | 'failed';

interface VaultState {
  status: VaultLoadStatus;
  loadError: string | null;
  items: VaultItem[];
  folders: VaultFolder[];
  categoryFolders: VaultCategoryFolders;
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
  // Added by the second vault migration; missing on a database without it.
  organization_id?: string | null;
  created_at: string;
  updated_at: string;
  vault_item_skills: { name: string; status: string }[] | null;
  vault_item_files: { id: string; file_name: string; mime_type: string; storage_path: string }[] | null;
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
    role: fileRole(file.storage_path),
  }));
  return {
    id: row.id,
    folderId: row.folder_id,
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
  if (error?.message?.toLowerCase().includes('fetch')) return VAULT_ERROR_NO_CONNECTION;
  return VAULT_ERROR_GENERIC;
}

/**
 * Your vault, read from and written to the same Supabase tables as the iPhone (docs/vault.md). Row-level security
 * keeps it to your own rows; after every change the vault is read again, so counts and folders match the server.
 */
export function useVault() {
  const supabase = useUntypedSupabase();
  const state = useState<VaultState>('vault', () => ({
    status: 'loading',
    loadError: null,
    items: [],
    folders: [],
    categoryFolders: {},
    problem: null,
  }));
  const shelves = computed(() => buildShelves(state.value.items, state.value.folders, state.value.categoryFolders));

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

  /**
   * Links to the logo and cover you added: the files whose names start with "logo-" and "cover-". An item saved
   * before covers were marked shows its first photo. Without a link the card shows its letter and colour, so a failure
   * is ignored.
   */
  async function loadImages(items: VaultItem[]) {
    const wanted: { itemId: string; role: 'logo' | 'cover'; path: string }[] = [];
    for (const item of items) {
      const photos = item.files.filter((file) => SHOWN_IMAGE_TYPES.includes(file.mimeType));
      const logo = photos.find((file) => file.role === 'logo');
      const cover = photos.find((file) => file.role === 'cover') ?? photos.find((file) => file.role === 'evidence');
      if (logo) wanted.push({ itemId: item.id, role: 'logo', path: logo.storagePath });
      if (cover) wanted.push({ itemId: item.id, role: 'cover', path: cover.storagePath });
    }
    const links = new Map<string, string>();
    if (!wanted.length) return links;
    const { data } = await supabase.storage.from(BUCKET).createSignedUrls(
      wanted.map((entry) => entry.path),
      IMAGE_LINK_SECONDS,
    );
    for (const link of data ?? []) {
      const entry = wanted.find((candidate) => candidate.path === link.path);
      if (entry && link.signedUrl) links.set(`${entry.role}:${entry.itemId}`, link.signedUrl);
    }
    return links;
  }

  /** What you changed about the standard folders; without it they look as in the design. */
  async function loadCategoryFolders() {
    const { data } = await supabase.auth.getUser();
    return readCategoryFolders(data.user?.user_metadata?.[METADATA_KEY]);
  }

  /** Shows the loading shapes only the first time; after that the vault stays while it refreshes. */
  async function load() {
    const [items, folders] = await Promise.all([
      supabase
        .from('vault_items')
        .select('*,vault_item_skills(name,status),vault_item_files(id,file_name,mime_type,storage_path)')
        .order('updated_at', { ascending: false }),
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
    const [logos, images, categoryFolders] = await Promise.all([
      loadLogos(rows),
      loadImages(loaded.map((entry) => entry.item!)),
      loadCategoryFolders(),
    ]);
    state.value.items = loaded.map(({ row, item }) => ({
      ...item!,
      logoUrl: (row.organization_id ? logos.get(row.organization_id) : undefined) ?? images.get(`logo:${item!.id}`) ?? null,
      coverUrl: images.get(`cover:${item!.id}`) ?? null,
    }));
    state.value.categoryFolders = categoryFolders;
    state.value.folders = (folders.data as FolderRow[]).map(toFolder);
    state.value.status = 'ready';
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

  /** Whether another folder in the row, standard or your own, already has this name. */
  function isFolderNameTaken(name: string, exceptKey?: string) {
    const wanted = name.trim().toLocaleLowerCase('nl');
    return shelves.value.some((entry) => entry.key !== exceptKey && entry.title.toLocaleLowerCase('nl') === wanted);
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

  function updateItem(itemId: string, draft: VaultItemDraft, folderId: string | null) {
    return perform(() => supabase.from('vault_items').update({ ...toVaultItemRow(draft), folder_id: folderId }).eq('id', itemId));
  }

  /** Null takes the item out of its folder; it stays in the vault. */
  function move(item: VaultItem, folderId: string | null) {
    return perform(() => supabase.from('vault_items').update({ folder_id: folderId }).eq('id', item.id));
  }

  /**
   * Into a standard folder: the item gets that category and leaves the folder it was in. A confirmed item keeps its
   * category (the database refuses), so only items you can change can go there.
   */
  function moveToCategory(item: VaultItem, category: VaultItemCategory) {
    return perform(() => supabase.from('vault_items').update({ category, folder_id: null }).eq('id', item.id));
  }

  /** Puts a new logo or cover on the card, or takes it off (null). The old picture is removed. */
  async function setImage(item: VaultItem, role: Exclude<VaultFileRole, 'evidence'>, file: File | null) {
    const { data: sessionData } = await supabase.auth.getSession();
    const userId = sessionData.session?.user.id;
    if (!userId) {
      state.value.problem = VAULT_ERROR_NOT_SIGNED_IN;
      return false;
    }
    const old = item.files.filter((entry) => entry.role === role);
    if (file) {
      const mimeType = getVaultMimeType(file);
      if (!mimeType?.startsWith('image/')) {
        state.value.problem = VAULT_COVER_TYPE;
        return false;
      }
      const path = `${userId}/${item.id}/${VAULT_FILE_PREFIXES[role]}${crypto.randomUUID()}.${getExtension(file.name)}`;
      const upload = await supabase.storage.from(BUCKET).upload(path, file, { contentType: mimeType, upsert: false });
      if (upload.error) {
        state.value.problem = messageFor(upload.error);
        return false;
      }
      const record = await supabase.from('vault_item_files').insert({
        item_id: item.id,
        storage_path: path,
        file_name: file.name.slice(0, 255),
        mime_type: mimeType,
        file_size_bytes: file.size,
      });
      if (record.error) {
        await supabase.storage.from(BUCKET).remove([path]);
        state.value.problem = messageFor(record.error);
        return false;
      }
    }
    if (old.length) {
      await supabase.storage.from(BUCKET).remove(old.map((entry) => entry.storagePath));
      await supabase.from('vault_item_files').delete().in('id', old.map((entry) => entry.id));
    }
    await load();
    return true;
  }

  /** Changes a standard folder, or removes it from the row (isHidden). Its items stay in the vault. */
  async function updateCategoryFolder(category: VaultItemCategory, change: VaultCategoryFolder | null) {
    const next: VaultCategoryFolders = { ...state.value.categoryFolders };
    if (change) next[category] = change;
    else delete next[category];
    const { error } = await supabase.auth.updateUser({ data: { [METADATA_KEY]: next } });
    if (error) {
      state.value.problem = messageFor(error);
      return false;
    }
    state.value.categoryFolders = next;
    return true;
  }

  /** Puts the standard folders you removed back in the row, as they were. */
  async function restoreCategoryFolders() {
    const next: VaultCategoryFolders = {};
    for (const [category, folder] of Object.entries(state.value.categoryFolders)) {
      if (!folder?.isHidden) next[category as VaultItemCategory] = folder;
    }
    const { error } = await supabase.auth.updateUser({ data: { [METADATA_KEY]: next } });
    if (error) {
      state.value.problem = messageFor(error);
      return false;
    }
    state.value.categoryFolders = next;
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
    updateItem,
    move,
    moveToCategory,
    setImage,
    remove,
    createFolder,
    updateFolder,
    deleteFolder,
    updateCategoryFolder,
    restoreCategoryFolders,
  };
}
