import type { VaultItemCategory, VaultItemDraft } from '~/types/vault';

interface OpenOptions {
  // Skills Ayla suggested in the conversation that opened "Kluis aanvullen".
  suggestedSkills?: string[];
  // Opened for a kind of evidence, or from a folder in the vault (iOS: "Bewijs toevoegen" in the folder you look at).
  category?: VaultItemCategory;
  folderId?: string | null;
}

interface VaultAddState {
  isOpen: boolean;
  // Changes on every open, so the dialog starts fresh.
  session: number;
  suggestedSkills: string[];
  category: VaultItemCategory | null;
  folderId: string | null;
}

export interface VaultSaveInput {
  draft: VaultItemDraft;
  folderIds: string[];
  // A folder for the kind that does not exist yet ("Stages"), made just before saving; null when none.
  newFolderName: string | null;
  documents: File[];
  cover: File | null;
  logo: File | null;
  skills: string[];
}

/**
 * What a save has done so far. The item is saved first; when a later part fails (a file, the skills), trying again
 * does only what is still missing, as on iOS, so nothing is added twice.
 */
export interface VaultSaveProgress {
  itemId: string | null;
  savedParts: Set<string>;
}

export function createSaveProgress(): VaultSaveProgress {
  return { itemId: null, savedParts: new Set() };
}

/**
 * "Kluis aanvullen": adding evidence to the vault in four steps, from anywhere in the app. It writes the tables iOS
 * also uses (docs/vault.md) through useVault: the item and its folders, its files in the private pave-vault bucket and
 * its skills. What you add yourself is always your own and not yet confirmed; the database refuses anything else.
 */
export function useVaultAdd() {
  const supabase = useUntypedSupabase();
  const vault = useVault();
  const state = useState<VaultAddState>('vault-add', () => ({
    isOpen: false,
    session: 0,
    suggestedSkills: [],
    category: null,
    folderId: null,
  }));

  function open(options: OpenOptions = {}) {
    state.value = {
      isOpen: true,
      session: state.value.session + 1,
      suggestedSkills: options.suggestedSkills ?? [],
      category: options.category ?? null,
      folderId: options.folderId ?? null,
    };
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

  /** Makes the folder of the kind just before saving, or finds it when it was made meanwhile. */
  async function kindFolderId(name: string, category: VaultItemCategory) {
    const made = await vault.createFolder(name, 'green', CATEGORY_FOLDER_ICON_KEYS[category]);
    vault.state.value.problem = null;
    return made?.id ?? vault.state.value.folders.find((folder) => folder.name.toLowerCase() === name.toLowerCase())?.id ?? null;
  }

  /** Saves what is still missing. Returns the message to show when a part failed; the progress says how far it got. */
  async function save(input: VaultSaveInput, progress: VaultSaveProgress): Promise<string | null> {
    try {
      if (!progress.itemId) {
        const folderIds = [...input.folderIds];
        if (input.newFolderName && input.draft.category) {
          const id = await kindFolderId(input.newFolderName, input.draft.category);
          if (id && !folderIds.includes(id)) folderIds.push(id);
        }
        progress.itemId = await vault.addItem(input.draft, folderIds);
      }
      const itemId = progress.itemId;
      for (const [index, file] of input.documents.entries()) {
        const key = `document:${index}`;
        if (progress.savedParts.has(key)) continue;
        await vault.attach(itemId, file, 'document');
        progress.savedParts.add(key);
      }
      for (const [role, file] of [['cover', input.cover], ['logo', input.logo]] as const) {
        if (!file || progress.savedParts.has(role)) continue;
        await vault.attach(itemId, file, role);
        progress.savedParts.add(role);
      }
      if (input.skills.length && !progress.savedParts.has('skills')) {
        await vault.addSkills(itemId, input.skills);
        progress.savedParts.add('skills');
      }
      // The vault page shows the new item straight away.
      vault.load();
      return null;
    } catch (error) {
      return error instanceof VaultSaveError ? error.message : VAULT_SAVE_FAILED;
    }
  }

  /** "Ayla mag dit document bekijken en gebruiken": the standing yes for this one item (vault_items.ayla_allowed_at). */
  async function allowAyla(itemId: string) {
    try {
      await vault.setAylaAllowed(itemId, true);
      vault.load();
      return null;
    } catch {
      return VAULT_CONSENT_FAILED;
    }
  }

  return { state, open, close, loadVaultSkills, save, allowAyla };
}
