import type { VaultEvidenceDocument, VaultEvidenceProposal, VaultItemCategory, VaultItemDraft } from '~/types/vault';
import type { VaultEvidenceReading } from '~/utils/vault/vaultAylaFill';
import type { AylaVaultItemProposal } from '~/types/ayla';

/** What Ayla already read in the chat, so the form opens filled in without reading the files again. */
export interface VaultAylaPrefill {
  files: File[];
  reading: VaultEvidenceReading;
  proposals: VaultEvidenceProposal[];
}

export type VaultChatSave = { status: 'saved'; title: string; itemId: string; hasLogo: boolean; hasCover: boolean } | { status: 'needsForm'; prefill: VaultAylaPrefill | null };

interface OpenOptions {
  // Skills Ayla suggested in the conversation that opened "Kluis aanvullen".
  suggestedSkills?: string[];
  // Opened for a kind of evidence, or from a folder in the vault (iOS: "Bewijs toevoegen" in the folder you look at).
  category?: VaultItemCategory;
  folderId?: string | null;
  // The files of the chat that offered to add this: the upload step is skipped and Ayla reads them straight away.
  documents?: File[];
  prefill?: VaultAylaPrefill | null;
  // "Zelf invullen" in the chat: the files come along, but Ayla reads nothing and fills in nothing.
  fillsMyself?: boolean;
}

interface VaultAddState {
  isOpen: boolean;
  // Changes on every open, so the dialog starts fresh.
  session: number;
  suggestedSkills: string[];
  category: VaultItemCategory | null;
  folderId: string | null;
  documents: File[];
  prefill: VaultAylaPrefill | null;
  fillsMyself: boolean;
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
    documents: [],
    prefill: null,
    fillsMyself: false,
  }));

  function open(options: OpenOptions = {}) {
    state.value = {
      isOpen: true,
      session: state.value.session + 1,
      suggestedSkills: options.suggestedSkills ?? [],
      category: options.category ?? null,
      folderId: options.folderId ?? null,
      documents: options.documents ?? [],
      prefill: options.prefill ?? null,
      fillsMyself: options.fillsMyself ?? false,
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

  /**
   * "Laat Ayla invullen": the documents that were read go to the Edge Function ayla-evidence, which proposes the whole
   * item (up to three when the files hold more than one). Only on request; nothing is stored there. Like iOS it waits
   * longer when photos go along, and says why it failed.
   */
  async function proposeEvidence(documents: VaultEvidenceDocument[], folders: string[], known: string[]): Promise<VaultEvidenceProposal[]> {
    const { data: session } = await supabase.auth.getSession();
    const token = session.session?.access_token;
    if (!token) throw new VaultSaveError(VAULT_AYLA_SKILLS_SIGNED_OUT);

    const { url, key } = useRuntimeConfig().public.supabase;
    let response: Response;
    try {
      response = await fetch(`${url}/functions/v1/ayla-evidence`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, apikey: key },
        body: JSON.stringify({ documents, folders, today: new Date().toISOString().slice(0, 10), known }),
        signal: AbortSignal.timeout(documents.some((document) => document.image) ? 75_000 : 50_000),
      });
    } catch (error) {
      if (import.meta.dev) console.error('ayla-evidence: no answer', error);
      throw new VaultSaveError(VAULT_AYLA_FILL_NO_CONNECTION);
    }
    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      if (import.meta.dev) console.error(`ayla-evidence: ${response.status}`, detail);
      const message =
        response.status === 404
          ? VAULT_AYLA_FILL_NOT_READY
          : response.status === 401
            ? VAULT_AYLA_SKILLS_SIGNED_OUT
            : response.status === 403
              ? INSUFFICIENT_AAL_MESSAGE
              : VAULT_AYLA_FILL_FAILED;
      throw new VaultSaveError(import.meta.dev ? `${message} [${response.status} ${detail.slice(0, 120)}]` : message);
    }
    const items = ((await response.json().catch(() => null)) as { items?: unknown } | null)?.items;
    if (!Array.isArray(items)) throw new VaultSaveError(VAULT_AYLA_FILL_FAILED);
    return items
      .filter((item): item is Partial<VaultEvidenceProposal> & { title: string } => typeof item?.title === 'string')
      .map((item) => ({
        category: item.category ?? 'other',
        title: item.title,
        organisationName: item.organisationName ?? null,
        organisationLocation: item.organisationLocation ?? null,
        startDate: item.startDate ?? null,
        endDate: item.endDate ?? null,
        issuedOn: item.issuedOn ?? null,
        isCurrent: item.isCurrent ?? false,
        description: item.description ?? null,
        skills: item.skills ?? [],
        folder: item.folder ?? null,
        documents: item.documents ?? [],
        coverDocument: item.coverDocument ?? null,
        coverBox: item.coverBox ?? null,
        logoDocument: item.logoDocument ?? null,
        logoBox: item.logoBox ?? null,
        website: item.website ?? null,
        sources: item.sources ?? {},
        logo: item.logo ?? null,
      }));
  }

  /**
   * A yes to "Zal ik het in je kluis zetten?" (iOS addEvidenceForUser): Ayla reads the chat's files and saves the item
   * without the form. When something required is missing, she sees more than one item, or reading or saving fails, the
   * form is needed instead, filled in with what she read, so nothing is saved halfway out of sight.
   */
  async function saveFromChat(files: File[], suggestedSkills: string[], chatItem?: AylaVaultItemProposal | null): Promise<VaultChatSave> {
    if (vault.state.value.status !== 'ready') await vault.load();
    // The files that belong to this item, when Ayla named them; else all of the chat's files.
    const itemFiles = new Set(chatItem?.attachments ?? []);
    const own = itemFiles.size ? files.filter((file) => itemFiles.has(file.name)) : files;
    const documents = (own.length ? own : files).slice(0, MAX_DOCUMENTS);
    const fromChat = chatItem?.title ? proposalFromChat(chatItem) : null;
    let prefill: VaultAylaPrefill;
    if (!documents.length) {
      // No files: what Ayla knows from the chat is all there is.
      if (!fromChat) return { status: 'needsForm', prefill: null };
      prefill = { files: [], reading: { documents: [] }, proposals: [fromChat] };
    } else {
      try {
        const reading = await readEvidence(documents);
        const known = await loadVaultSkills();
        const proposals = await proposeEvidence(reading.documents, vault.state.value.folders.map((folder) => folder.name), known);
        // One item: completed with what the user told in the chat.
        const completed = proposals.length === 1 && chatItem?.title ? [mergedWithChat(proposals[0]!, chatItem)] : proposals;
        prefill = { files: documents, reading, proposals: completed.length ? completed : fromChat ? [fromChat] : [] };
      } catch {
        return { status: 'needsForm', prefill: fromChat ? { files: documents, reading: { documents: [] }, proposals: [fromChat] } : null };
      }
    }
    const [proposal] = prefill.proposals;
    if (!proposal || prefill.proposals.length > 1) return { status: 'needsForm', prefill };

    const draft = applyProposal(proposal, createDraft());
    if (Object.keys(checkDraft(draft)).length) return { status: 'needsForm', prefill };

    const folders = vault.state.value.folders;
    const category = draft.category || 'other';
    const folderIds: string[] = [];
    const ownKind = kindFolder(category, folders);
    if (ownKind) folderIds.push(ownKind.id);
    const named = proposal.folder?.toLowerCase();
    const chosen = named ? folders.find((folder) => folder.name.toLowerCase() === named) : null;
    if (chosen && !folderIds.includes(chosen.id)) folderIds.push(chosen.id);
    const pictures = await aylaPictures(proposal, documents, prefill.reading, true, true);
    // In development: where Ayla saw the logo and cover, to tell a missing one apart from one that could not be cut.
    if (import.meta.dev) {
      console.info('ayla-evidence: logo and cover', {
        logoDocument: proposal.logoDocument,
        logoBox: proposal.logoBox,
        website: proposal.website,
        websiteLogo: Boolean(proposal.logo),
        coverDocument: proposal.coverDocument,
        coverBox: proposal.coverBox,
        gotLogo: Boolean(pictures.logo),
        gotCover: Boolean(pictures.cover),
      });
    }
    const skills = new Map<string, string>();
    for (const name of [...proposal.skills.map((skill) => skill.name), ...suggestedSkills]) {
      const trimmed = name.trim();
      if (trimmed && !skills.has(trimmed.toLowerCase())) skills.set(trimmed.toLowerCase(), trimmed);
    }
    const progress = createSaveProgress();
    const problem = await save(
      {
        draft,
        folderIds,
        newFolderName: ownKind ? null : VAULT_CATEGORY_PLURALS[category],
        documents,
        cover: pictures.cover,
        logo: pictures.logo,
        skills: [...skills.values()],
      },
      progress,
    );
    // Once the item exists it is not offered again in the form: that would add it twice.
    if (problem && !progress.itemId) return { status: 'needsForm', prefill };
    return { status: 'saved', title: draft.title, itemId: progress.itemId!, hasLogo: Boolean(pictures.logo), hasCover: Boolean(pictures.cover) };
  }

  return { state, open, close, loadVaultSkills, save, allowAyla, proposeEvidence, saveFromChat };
}
