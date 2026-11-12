import type { VaultItemDraft } from '~/types/vault';

const BUCKET = 'pave-vault';

interface OpenOptions {
  // Skills Ayla suggested in the conversation that opened "Kluis aanvullen".
  suggestedSkills?: string[];
}

interface VaultAddState {
  isOpen: boolean;
  // Changes every time it opens, so the dialog starts empty again.
  session: number;
  suggestedSkills: string[];
}

export interface VaultSaveInput {
  draft: VaultItemDraft;
  file: File | null;
  cover: File | null;
  skills: string[];
}

type SaveResult = { itemId: string; error: null } | { itemId: null; error: string };

function errorMessage(error: { code?: string; message?: string } | null) {
  if (isMissingTable(error) || isMissingColumn(error)) return VAULT_SAVE_NOT_READY;
  if (error?.code === 'PGRST301' || error?.code === '401') return VAULT_SAVE_NOT_SIGNED_IN;
  return VAULT_SAVE_FAILED;
}

/**
 * "Kluis aanvullen": adding evidence to the vault in four steps, from anywhere in the app. It writes the tables iOS
 * also uses (docs/vault.md): the item, its files in the private pave-vault bucket and its skills. What you add yourself
 * is always your own and not yet confirmed; the database refuses anything else.
 */
export function useVaultAdd() {
  const supabase = useUntypedSupabase();
  const state = useState<VaultAddState>('vault-add', () => ({ isOpen: false, session: 0, suggestedSkills: [] }));

  function open(options: OpenOptions = {}) {
    state.value = { isOpen: true, session: state.value.session + 1, suggestedSkills: options.suggestedSkills ?? [] };
  }

  function close() {
    state.value.isOpen = false;
  }

  /** The skill names already in the vault, for "Vaardigheden uit mijn kluis". */
  async function loadVaultSkills() {
    const { data, error } = await supabase.from('vault_item_skills').select('name').eq('status', 'accepted');
    if (error || !data) return [];
    const byKey = new Map<string, string>();
    for (const row of data as { name: string }[]) {
      const name = row.name.trim();
      if (name && !byKey.has(name.toLowerCase())) byKey.set(name.toLowerCase(), name);
    }
    return [...byKey.values()].sort((a, b) => a.localeCompare(b, 'nl'));
  }

  async function uploadFile(userId: string, itemId: string, file: File) {
    const path = `${userId}/${itemId}/${crypto.randomUUID()}.${getExtension(file.name)}`;
    const mimeType = getVaultMimeType(file)!;
    const upload = await supabase.storage.from(BUCKET).upload(path, file, { contentType: mimeType, upsert: false });
    if (upload.error) return { path: null, error: upload.error };
    const record = await supabase.from('vault_item_files').insert({
      item_id: itemId,
      storage_path: path,
      file_name: file.name.slice(0, 255),
      mime_type: mimeType,
      file_size_bytes: file.size,
    });
    return { path, error: record.error };
  }

  /** Takes a half-saved item away again: Storage objects first (the database cannot), then the item and its rows. */
  async function removeItem(itemId: string, paths: string[]) {
    if (paths.length) await supabase.storage.from(BUCKET).remove(paths);
    await supabase.from('vault_items').delete().eq('id', itemId);
  }

  async function save(input: VaultSaveInput): Promise<SaveResult> {
    const { data: sessionData } = await supabase.auth.getSession();
    const userId = sessionData.session?.user.id;
    if (!userId) return { itemId: null, error: VAULT_SAVE_NOT_SIGNED_IN };

    const item = await supabase.from('vault_items').insert(toVaultItemRow(input.draft)).select('id').single();
    if (item.error || !item.data) return { itemId: null, error: errorMessage(item.error) };
    const itemId = (item.data as { id: string }).id;

    const uploaded: string[] = [];
    // The cover is kept as an image file of the item: vault_items has no cover column yet.
    for (const file of [input.file, input.cover]) {
      if (!file) continue;
      const result = await uploadFile(userId, itemId, file);
      if (result.path) uploaded.push(result.path);
      if (result.error) {
        await removeItem(itemId, uploaded);
        return { itemId: null, error: errorMessage(result.error) };
      }
    }

    if (input.skills.length) {
      const skills = await supabase.from('vault_item_skills').insert(input.skills.map((name) => ({ item_id: itemId, name })));
      if (skills.error) {
        await removeItem(itemId, uploaded);
        return { itemId: null, error: errorMessage(skills.error) };
      }
    }

    return { itemId, error: null };
  }

  /** "Ayla mag dit document bekijken en gebruiken": the standing yes for this one item (vault_items.ayla_allowed_at). */
  async function allowAyla(itemId: string) {
    const { error } = await supabase.from('vault_items').update({ ayla_allowed_at: new Date().toISOString() }).eq('id', itemId);
    return error ? VAULT_CONSENT_FAILED : null;
  }

  return { state, open, close, loadVaultSkills, save, allowAyla };
}
