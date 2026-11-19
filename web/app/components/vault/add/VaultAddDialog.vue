<script setup lang="ts">
import type { VaultAddStep, VaultEvidenceProposal, VaultItemDraft } from '~/types/vault';
import type { VaultEvidenceReading } from '~/utils/vault/vaultAylaFill';
import type { DraftField } from '~/utils/vault/vaultAdd';

// "Bewijs toevoegen" (iOS VaultAddEvidenceSheet, Figma FEDDIES 1348:1169 to 1348:2537): four steps in one window, with
// what iOS has (VaultAddEvidenceModel): up to five documents, several folders, a logo and a cover with the card shown
// live, and Ayla's proposals for skills. Nothing is saved until the skills step; after that the item exists and only
// what is still missing is tried again. The last card asks whether Ayla may use it. Closing halfway asks first.
const vaultAdd = useVaultAdd();
const vault = useVault();

const STEP_INDEX: Record<VaultAddStep, number> = { basis: 0, details: 0, cover: 1, skills: 2, done: 3 };

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const contentRef = useTemplateRef<HTMLDivElement>('content');
const detailsRef = useTemplateRef<{ focusFirstProblem: (field: DraftField) => void }>('details');
const discardRef = useTemplateRef<{ open: () => void }>('discard');
const titleId = useId();

const step = ref<VaultAddStep>('basis');
const documents = ref<File[]>([]);
const draft = ref<VaultItemDraft>(createDraft());
const folderIds = ref<string[]>([]);
// New evidence goes in the folder of its kind; that follows the kind until you choose folders yourself (as on iOS).
const foldersFollowKind = ref(true);
const kindFolderIdNow = ref<string | null>(null);
const makesKindFolder = ref(true);
const showsProblems = ref(false);
const wantsCover = ref(false);
const cover = ref<File | null>(null);
const logo = ref<File | null>(null);
const coverProblem = ref<string | null>(null);
const skills = ref<string[]>([]);
const vaultSkills = ref<string[]>([]);
const isLoadingSkills = ref(false);
const isSaving = ref(false);
const saveError = ref<string | null>(null);
const progress = ref(createSaveProgress());
const allowsAyla = ref(false);

// "Laat Ayla invullen" (iOS VaultAddEvidenceModel+Fill): she reads the files and fills in the form, only after you ask.
// What she did not see in the files stays empty; you check everything. More than one item stays one item unless you add
// them apart.
type AylaFill = 'idle' | 'reading' | 'filled' | 'failed';
interface NextEvidence {
  proposal: VaultEvidenceProposal;
  files: File[];
  reading: VaultEvidenceReading;
}
const aylaFill = ref<AylaFill>('idle');
const isByAyla = ref(false);
const aylaProposal = ref<VaultEvidenceProposal | null>(null);
const aylaProposals = ref<VaultEvidenceProposal[]>([]);
const aylaDraft = ref<VaultItemDraft | null>(null);
const aylaFiles = ref<File[]>([]);
const aylaReading = ref<VaultEvidenceReading>({ documents: [] });
const aylaLogoSource = ref<string | null>(null);
const aylaChoseLogo = ref(false);
const aylaChoseCover = ref(false);
const addsApart = ref(false);
const nextEvidence = ref<NextEvidence[]>([]);
const aylaSkillNames = ref<string[]>([]);
// A late answer of a read that was stopped changes nothing.
let fillRun = 0;

// Closed before saving, also by accident: it comes back as it was when you add evidence within half a minute (iOS
// keepDraft). Ayla's reading is not kept; the form she filled in is.
const DRAFT_KEPT_MS = 30_000;
interface KeptDraft {
  at: number;
  step: VaultAddStep;
  documents: File[];
  draft: VaultItemDraft;
  folderIds: string[];
  foldersFollowKind: boolean;
  wantsCover: boolean;
  cover: File | null;
  logo: File | null;
  skills: string[];
  isByAyla: boolean;
}
const kept = useState<KeptDraft | null>('vault-add-kept-draft', () => null);
const isResumed = ref(false);

const logoUrl = useObjectUrl(logo);
const coverUrl = useObjectUrl(cover);

const stepIndex = computed(() => STEP_INDEX[step.value]);
const isDone = computed(() => step.value === 'done');
const isSaved = computed(() => progress.value.itemId !== null);
const problems = computed(() => (showsProblems.value ? checkDraft(draft.value) : {}));
// The kind has no folder yet: one with its name (such as Stages) is offered and made when you save.
const newKindFolderName = computed(() =>
  draft.value.category && !kindFolder(draft.value.category, vault.state.value.folders)
    ? VAULT_CATEGORY_PLURALS[draft.value.category]
    : null,
);
const aylaSplitTitles = computed(() => (aylaProposals.value.length > 1 ? aylaProposals.value.map((proposal) => proposal.title) : null));
const notes = computed(() => aylaNotes(aylaProposal.value, draft.value, aylaDraft.value));
const logoNote = computed(() => (aylaChoseLogo.value && logo.value ? VAULT_AYLA_LOGO_NOTE(aylaLogoSource.value) : null));
const coverNote = computed(() => (aylaChoseCover.value && cover.value ? VAULT_AYLA_COVER_NOTE : null));
const offersAyla = computed(() => step.value === 'basis' && documents.value.length > 0 && aylaFill.value !== 'filled');
const suggestedSkills = computed(() => [...new Set([...vaultAdd.state.value.suggestedSkills, ...aylaSkillNames.value])]);
const isDirty = computed(
  () =>
    Boolean(documents.value.length || cover.value || logo.value || skills.value.length) ||
    Object.entries(draft.value).some(([key, value]) => key !== 'usesPeriod' && String(value).trim() !== ''),
);

function reset() {
  step.value = 'basis';
  documents.value = [];
  draft.value = createDraft();
  folderIds.value = vaultAdd.state.value.folderId ? [vaultAdd.state.value.folderId] : [];
  foldersFollowKind.value = true;
  kindFolderIdNow.value = null;
  makesKindFolder.value = true;
  showsProblems.value = false;
  wantsCover.value = false;
  cover.value = null;
  logo.value = null;
  coverProblem.value = null;
  skills.value = [];
  saveError.value = null;
  progress.value = createSaveProgress();
  allowsAyla.value = false;
  isResumed.value = false;
  fillRun += 1;
  aylaFill.value = 'idle';
  isByAyla.value = false;
  aylaProposal.value = null;
  aylaProposals.value = [];
  aylaDraft.value = null;
  aylaFiles.value = [];
  aylaReading.value = { documents: [] };
  aylaLogoSource.value = null;
  aylaChoseLogo.value = false;
  aylaChoseCover.value = false;
  addsApart.value = false;
  nextEvidence.value = [];
  aylaSkillNames.value = [];
}

async function loadSkills() {
  isLoadingSkills.value = true;
  vaultSkills.value = await vaultAdd.loadVaultSkills();
  isLoadingSkills.value = false;
}

watch(
  () => vaultAdd.state.value.isOpen,
  (isOpen) => {
    if (!isOpen) {
      keepDraft();
      dialogRef.value?.close();
      return;
    }
    reset();
    // "Zelf invullen" starts clean: an earlier form, perhaps one Ayla filled in, does not come back.
    if (vaultAdd.state.value.fillsMyself) kept.value = null;
    else resumeDraft();
    dialogRef.value?.showModal();
    openWithChatFiles(loadSkills(), vault.state.value.status !== 'ready' ? vault.load() : Promise.resolve());
  },
);

/** The folder of the kind comes along with the kind, until you tick folders yourself. */
watch(
  () => [draft.value.category, vault.state.value.folders] as const,
  ([category]) => {
    if (!foldersFollowKind.value || !category) return;
    const folder = kindFolder(category, vault.state.value.folders)?.id ?? null;
    let ids = folderIds.value.filter((id) => id !== kindFolderIdNow.value);
    if (folder && !ids.includes(folder)) ids = [...ids, folder];
    folderIds.value = ids;
    kindFolderIdNow.value = folder;
  },
);

/**
 * "Zet in de kluis" in a chat with files (iOS VaultAddEvidenceModel.proposed): the files of the chat are already there, so
 * the upload step is skipped and Ayla reads them straight away. Without files the dialog starts as usual.
 */
async function openWithChatFiles(...loading: Promise<unknown>[]) {
  const given = vaultAdd.state.value.documents.slice(0, MAX_DOCUMENTS);
  const prefill = vaultAdd.state.value.prefill;
  await Promise.all(loading);
  if ((!given.length && !prefill?.proposals.length) || documents.value.length || !vaultAdd.state.value.isOpen) return;
  // "Zelf invullen": the files are there, the form is empty, and you start on the details yourself.
  if (vaultAdd.state.value.fillsMyself) {
    documents.value = given;
    if (given.length) startDetails();
    return;
  }
  documents.value = given;
  if (given[0] && !draft.value.title.trim()) draft.value.title = suggestedTitle(given[0].name);
  // Ayla already read them in the chat: the form opens filled in, without reading them again.
  if (prefill?.proposals.length) await receiveAyla(prefill.files, prefill.reading, prefill.proposals, fillRun);
  else await fillWithAyla();
}

function keepDraft() {
  if (isSaved.value || !isDirty.value) {
    kept.value = null;
    return;
  }
  kept.value = {
    at: Date.now(),
    // A step of Ayla's reading goes back to the first step; the form she filled in stays as it is.
    step: step.value === 'done' ? 'basis' : step.value,
    documents: documents.value,
    draft: draft.value,
    folderIds: folderIds.value,
    foldersFollowKind: foldersFollowKind.value,
    wantsCover: wantsCover.value,
    cover: cover.value,
    logo: logo.value,
    skills: skills.value,
    isByAyla: isByAyla.value,
  };
}

async function resumeDraft() {
  const back = kept.value;
  kept.value = null;
  if (!back || Date.now() - back.at > DRAFT_KEPT_MS) return;
  documents.value = back.documents;
  draft.value = back.draft;
  folderIds.value = back.folderIds;
  foldersFollowKind.value = back.foldersFollowKind;
  wantsCover.value = back.wantsCover;
  cover.value = back.cover;
  logo.value = back.logo;
  skills.value = back.skills;
  isByAyla.value = back.isByAyla;
  step.value = back.step;
  // The step watcher below clears the notice for a step change; this one is not the user's.
  await nextTick();
  isResumed.value = true;
  announce(VAULT_DRAFT_BACK);
}

function startOver() {
  reset();
  isResumed.value = false;
}

// Every new step starts at the top, and a screen reader hears where it is.
watch(step, async () => {
  isResumed.value = false;
  await nextTick();
  contentRef.value?.scrollTo({ top: 0 });
  contentRef.value?.focus({ preventScroll: true });
});

function goTo(next: VaultAddStep) {
  saveError.value = null;
  step.value = next;
}

function startDetails() {
  if (!draft.value.category) draft.value.category = vaultAdd.state.value.category ?? 'projects';
  goTo('details');
}

/** A picked file keeps you on the first step, so you can add more; its name is a first guess at the title. */
function pickDocument(picked: File) {
  if (documents.value.length >= MAX_DOCUMENTS) return;
  if (documents.value.some((file) => file.name === picked.name && file.size === picked.size)) return;
  documents.value = [...documents.value, picked];
  if (!draft.value.title.trim()) draft.value.title = suggestedTitle(picked.name);
  saveError.value = null;
  documentsChangedByUser();
}

function removeDocument(index: number) {
  documents.value = documents.value.filter((_, position) => position !== index);
  documentsChangedByUser();
}

/**
 * Other documents than Ayla read: what she is reading now no longer fits, a failed try may be tried again, and her split
 * into several items no longer matches, so it stays one item with the documents you chose.
 */
function documentsChangedByUser() {
  if (aylaFill.value === 'reading') stopFilling();
  if (aylaFill.value === 'failed') aylaFill.value = 'idle';
  if (aylaProposals.value.length > 1) {
    aylaProposals.value = [];
    addsApart.value = false;
    nextEvidence.value = [];
  }
}

async function fillWithAyla() {
  if (!documents.value.length || aylaFill.value === 'reading') return;
  const run = (fillRun += 1);
  aylaFill.value = 'reading';
  saveError.value = null;
  const files = [...documents.value];
  try {
    const reading = await readEvidence(files);
    const proposals = await vaultAdd.proposeEvidence(
      reading.documents,
      vault.state.value.folders.map((folder) => folder.name),
      vaultSkills.value,
    );
    if (run !== fillRun) return;
    await receiveAyla(files, reading, proposals, run);
  } catch (error) {
    if (run !== fillRun) return;
    aylaFill.value = 'failed';
    saveError.value = error instanceof VaultSaveError ? error.message : VAULT_AYLA_FILL_FAILED;
  }
}

/** Ayla's reading in the form: the first item she saw, and the others to add apart if you want. */
async function receiveAyla(files: File[], reading: VaultEvidenceReading, proposals: VaultEvidenceProposal[], run: number) {
  if (!proposals.length) {
    aylaFill.value = 'failed';
    saveError.value = VAULT_AYLA_FILL_EMPTY;
    return;
  }
  aylaFiles.value = files;
  aylaReading.value = reading;
  aylaProposals.value = proposals;
  addsApart.value = false;
  nextEvidence.value = [];
  await applyAyla(proposals[0]!, files, reading);
  if (run !== fillRun) return;
  aylaFill.value = 'filled';
  announce(VAULT_AYLA_FILLED_ANNOUNCEMENT);
  goTo('details');
}

/** "Zelf invullen": Ayla stops at once, and a late answer changes nothing. */
function stopFilling() {
  fillRun += 1;
  if (aylaFill.value === 'reading') aylaFill.value = 'idle';
}

function skipAyla() {
  stopFilling();
  next();
}

/** A screen reader hears what Ayla did. */
function announce(message: string) {
  const live = document.getElementById('vault-add-live');
  if (live) live.textContent = message;
}

/** Fills the form with one of Ayla's items, with its folder, skills, logo and cover. */
async function applyAyla(proposal: VaultEvidenceProposal, files: File[], reading: VaultEvidenceReading) {
  draft.value = applyProposal(proposal, draft.value);
  isByAyla.value = true;
  const named = proposal.folder?.toLowerCase();
  const folder = named ? vault.state.value.folders.find((candidate) => candidate.name.toLowerCase() === named) : null;
  if (folder && !folderIds.value.includes(folder.id)) folderIds.value = [...folderIds.value, folder.id];
  const names = new Map<string, string>();
  for (const skill of proposal.skills) {
    const name = skill.name.trim();
    if (name && !names.has(name.toLowerCase())) names.set(name.toLowerCase(), name);
  }
  skills.value = [...names.values()];
  aylaSkillNames.value = skills.value;
  const pictures = await aylaPictures(proposal, files, reading, !logo.value, !cover.value);
  if (pictures.logo) {
    logo.value = pictures.logo;
    aylaChoseLogo.value = true;
    aylaLogoSource.value = pictures.logoSource;
  }
  if (pictures.cover) {
    cover.value = pictures.cover;
    wantsCover.value = true;
    aylaChoseCover.value = true;
  }
  aylaProposal.value = proposal;
  aylaDraft.value = { ...draft.value };
}

/** Apart: this item keeps its own documents, and the others follow one by one. Not apart: one item with all documents. */
function setAddsApart(apart: boolean) {
  const [first, ...others] = aylaProposals.value;
  if (!first || aylaProposals.value.length < 2) return;
  addsApart.value = apart;
  if (apart) {
    const mine = first.documents.filter((index) => aylaFiles.value[index]).map((index) => aylaFiles.value[index]!);
    documents.value = mine.length ? mine : [...aylaFiles.value];
    nextEvidence.value = others.map((proposal) => {
      const indexes = proposal.documents.filter((index) => aylaFiles.value[index]);
      return {
        proposal: renumbered(proposal, indexes),
        files: indexes.map((index) => aylaFiles.value[index]!),
        reading: { documents: indexes.map((index) => aylaReading.value.documents[index]!) },
      };
    });
  } else {
    documents.value = [...aylaFiles.value];
    nextEvidence.value = [];
  }
}

watch(addsApart, (apart, before) => {
  if (apart !== before && aylaProposals.value.length > 1) setAddsApart(apart);
});

/** The next item Ayla saw, as its own round that starts at the details, already filled in. */
async function startNext() {
  const [upcoming, ...rest] = nextEvidence.value;
  if (!upcoming) return;
  // Everything that belongs to the saved item goes; what is left of Ayla's split carries on.
  reset();
  documents.value = upcoming.files;
  aylaFiles.value = upcoming.files;
  aylaReading.value = upcoming.reading;
  await applyAyla(upcoming.proposal, upcoming.files, upcoming.reading);
  nextEvidence.value = rest;
  aylaFill.value = 'filled';
  goTo('details');
}

function addWithoutFile() {
  documents.value = [];
  startDetails();
}

function checkDetails() {
  showsProblems.value = true;
  const missing = Object.keys(checkDraft(draft.value)) as DraftField[];
  if (missing.length) {
    detailsRef.value?.focusFirstProblem(missing[0]!);
    return;
  }
  goTo('cover');
}

function checkCover() {
  if (wantsCover.value && !cover.value) {
    coverProblem.value = VAULT_PROBLEM_COVER;
    return;
  }
  coverProblem.value = null;
  goTo('skills');
}

function pickImage(role: 'logo' | 'cover', file: File) {
  if (role === 'logo') logo.value = file;
  else {
    cover.value = file;
    coverProblem.value = null;
  }
}

function removeImage(role: 'logo' | 'cover') {
  if (role === 'logo') logo.value = null;
  else cover.value = null;
}

async function saveItem() {
  isSaving.value = true;
  saveError.value = await vaultAdd.save(
    {
      draft: draft.value,
      folderIds: folderIds.value,
      newFolderName: newKindFolderName.value && makesKindFolder.value ? newKindFolderName.value : null,
      documents: documents.value,
      cover: wantsCover.value ? cover.value : null,
      logo: logo.value,
      skills: skills.value,
      isByAyla: isByAyla.value,
    },
    progress.value,
  );
  isSaving.value = false;
  if (!saveError.value) goTo('done');
}

function next() {
  if (step.value === 'basis') {
    if (documents.value.length) startDetails();
    else saveError.value = VAULT_PROBLEM_FILE;
  } else if (step.value === 'details') checkDetails();
  else if (step.value === 'cover') checkCover();
  else if (step.value === 'skills') saveItem();
}

/** Back is gone once the item is saved: changing the details then would not reach the vault (as on iOS). */
function back() {
  if (step.value === 'details') goTo('basis');
  else if (step.value === 'cover') goTo('details');
  else if (step.value === 'skills') goTo('cover');
}

async function finish(continueWithNext = false) {
  if (allowsAyla.value && progress.value.itemId) {
    isSaving.value = true;
    saveError.value = await vaultAdd.allowAyla(progress.value.itemId);
    isSaving.value = false;
    if (saveError.value) return;
  }
  if (continueWithNext && nextEvidence.value.length) await startNext();
  else vaultAdd.close();
}

/** ✕, Escape or a click next to the card. Once saved it simply closes; halfway it asks first. */
function requestClose() {
  if (isSaving.value) return;
  if (!isSaved.value && isDirty.value) discardRef.value?.open();
  else vaultAdd.close();
}

function handleCancel(event: Event) {
  event.preventDefault();
  requestClose();
}

function handleBackdropClick(event: MouseEvent) {
  if (event.target === dialogRef.value) requestClose();
}

// The dialog closes by itself on Escape in some browsers; keep the shared state in step.
function handleClose() {
  if (vaultAdd.state.value.isOpen) vaultAdd.close();
}
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    :class="isDone ? 'max-w-120' : 'max-w-154'"
    class="m-auto max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] overflow-hidden rounded-modal bg-white p-0 text-heading shadow-modal backdrop:bg-backdrop"
    @cancel="handleCancel"
    @close="handleClose"
    @click="handleBackdropClick"
  >
    <VaultAddDone
      v-if="isDone"
      v-model:allows-ayla="allowsAyla"
      :title-id="titleId"
      :is-saving="isSaving"
      :has-file="documents.length > 0"
      :problem="saveError"
      :next-title="nextEvidence[0]?.proposal.title ?? null"
      @finish="finish(false)"
      @next="finish(true)"
    />

    <div v-else class="flex max-h-[calc(100dvh-2rem)] flex-col">
      <div class="flex items-center justify-between gap-4 px-9 pt-8 max-sm:px-5">
        <h2 :id="titleId" class="font-heading text-2xl font-semibold text-heading">{{ VAULT_ADD_TITLE }}</h2>
        <button
          type="button"
          :aria-label="VAULT_ADD_CLOSE"
          :title="VAULT_ADD_CLOSE"
          class="-mr-2 flex size-9 shrink-0 items-center justify-center rounded-field hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="requestClose"
        >
          <VaultIcon src="/images/vault/close.svg" :width="13.6909" :height="13.6909" class="text-brand" />
        </button>
      </div>

      <VaultAddSteps class="mx-9 mt-6 max-sm:mx-5" :current="stepIndex" />

      <div v-if="isResumed" class="mx-9 mt-4 flex items-center gap-3 rounded-xl bg-surface px-3.5 max-sm:mx-5">
        <p class="min-w-0 flex-1 py-2.5 text-xs font-medium text-heading">{{ VAULT_DRAFT_BACK }}</p>
        <button
          type="button"
          class="min-h-10 shrink-0 text-sm font-semibold text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand"
          @click="startOver"
        >
          {{ VAULT_DRAFT_START_OVER }}
        </button>
      </div>

      <div
        ref="content"
        tabindex="-1"
        autofocus
        :aria-label="`${VAULT_ADD_STEPS[stepIndex]} (${stepIndex + 1}/${VAULT_ADD_STEPS.length})`"
        class="min-h-0 flex-1 overflow-y-auto px-9 pb-1 pt-6 focus:outline-none max-sm:px-5"
      >
        <VaultBasisStep
          v-if="step === 'basis'"
          :files="documents"
          :is-reading="aylaFill === 'reading'"
          @pick="pickDocument"
          @remove-file="removeDocument"
          @without-file="addWithoutFile"
        />
        <VaultDetailsStep
          v-else-if="step === 'details'"
          ref="details"
          v-model:draft="draft"
          v-model:folder-ids="folderIds"
          v-model:makes-new-folder="makesKindFolder"
          :files="documents"
          :problems="problems"
          :new-folder-name="newKindFolderName"
          :notes="notes"
          @remove-file="removeDocument"
          @folders-chosen="foldersFollowKind = false"
        >
          <template v-if="aylaProposal" #top>
            <VaultAylaFilledBanner v-model:adds-apart="addsApart" :split-titles="aylaSplitTitles" />
          </template>
        </VaultDetailsStep>
        <div v-else-if="step === 'cover'" class="flex flex-col gap-8">
          <VaultLookSection
            v-model:wants-cover="wantsCover"
            :logo-url="logoUrl"
            :cover-url="coverUrl"
            :title="draft.title"
            :organisation-name="draft.organisationName"
            :category="draft.category"
            :problem="coverProblem"
            :has-logo="Boolean(logo)"
            :file-name="documents[0]?.name"
            :logo-note="logoNote"
            :cover-note="coverNote"
            @pick="pickImage"
            @remove="removeImage"
          />
          <VaultDocumentsSection :files="documents" @pick="pickDocument" @remove-file="removeDocument" />
        </div>
        <VaultSkillsStep
          v-else
          v-model:selected="skills"
          :vault-skills="vaultSkills"
          :ayla-skills="suggestedSkills"
          :is-loading="isLoadingSkills"
          :draft="draft"
          :documents="documents"
          asks-ayla-on-mount
        />
      </div>

      <!-- Step 1 without a file has two clear choices and no button (as on iOS). -->
      <div v-if="step === 'basis' && !documents.length" class="pb-8" />
      <div v-else class="px-9 pb-8 pt-6 max-sm:px-5">
        <p v-if="saveError" role="alert" class="mb-3 text-sm text-danger">{{ saveError }}</p>
        <div class="flex justify-end gap-2.5">
          <button
            v-if="offersAyla"
            type="button"
            class="min-h-10 min-w-25.75 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            @click="skipAyla"
          >
            {{ VAULT_AYLA_FILL_STOP }}
          </button>
          <button
            v-if="step !== 'basis' && !isSaved"
            type="button"
            :disabled="isSaving"
            class="min-h-10 min-w-25.75 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
            @click="back"
          >
            {{ VAULT_ADD_BACK }}
          </button>
          <button
            type="button"
            :disabled="isSaving || aylaFill === 'reading'"
            :aria-busy="isSaving || aylaFill === 'reading'"
            class="min-h-10 min-w-28.5 rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-60"
            @click="offersAyla ? fillWithAyla() : next()"
          >
            {{
              offersAyla
                ? aylaFill === 'reading'
                  ? VAULT_AYLA_FILL_READING_BUTTON
                  : aylaFill === 'failed'
                    ? VAULT_AYLA_FILL_AGAIN
                    : VAULT_AYLA_FILL
                : isSaving
                  ? VAULT_ADD_SAVING
                  : step === 'skills'
                    ? VAULT_ADD_BUTTON
                    : VAULT_ADD_NEXT
            }}
          </button>
        </div>
      </div>
    </div>

    <p id="vault-add-live" class="sr-only" role="status" aria-live="polite" />

    <LayoutConfirmSheet
      ref="discard"
      :title="VAULT_DISCARD_TITLE"
      :message="VAULT_DISCARD_MESSAGE"
      :confirm-label="VAULT_DISCARD_CONFIRM"
      :cancel-label="VAULT_DISCARD_KEEP"
      @confirm="vaultAdd.close()"
    />
  </dialog>
</template>
