<script setup lang="ts">
import type { VaultAddStep, VaultItemDraft } from '~/types/vault';
import type { DraftField } from '~/utils/vaultAdd';

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
      dialogRef.value?.close();
      return;
    }
    reset();
    dialogRef.value?.showModal();
    loadSkills();
    if (vault.state.value.status !== 'ready') vault.load();
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

// Every new step starts at the top, and a screen reader hears where it is.
watch(step, async () => {
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
}

function removeDocument(index: number) {
  documents.value = documents.value.filter((_, position) => position !== index);
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

async function finish() {
  if (allowsAyla.value && progress.value.itemId) {
    isSaving.value = true;
    saveError.value = await vaultAdd.allowAyla(progress.value.itemId);
    isSaving.value = false;
    if (saveError.value) return;
  }
  vaultAdd.close();
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
      @finish="finish"
    />

    <div v-else class="flex max-h-[calc(100dvh-2rem)] flex-col">
      <div class="flex items-center justify-between gap-4 px-9 pt-8 max-sm:px-5">
        <h2 :id="titleId" class="font-heading text-2xl font-semibold text-heading">{{ VAULT_ADD_TITLE }}</h2>
        <button
          type="button"
          :aria-label="VAULT_ADD_CLOSE"
          :title="VAULT_ADD_CLOSE"
          class="flex h-9.25 w-8.75 shrink-0 items-center justify-center rounded-field border border-field-line hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="requestClose"
        >
          <img src="/images/vault/close.svg" alt="" width="13.6909" height="13.6909" />
        </button>
      </div>

      <VaultAddSteps class="mx-9 mt-6 max-sm:mx-5" :current="stepIndex" />

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
          @remove-file="removeDocument"
          @folders-chosen="foldersFollowKind = false"
        />
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
            @pick="pickImage"
            @remove="removeImage"
          />
          <VaultDocumentsSection :files="documents" @pick="pickDocument" @remove-file="removeDocument" />
        </div>
        <VaultSkillsStep
          v-else
          v-model:selected="skills"
          :vault-skills="vaultSkills"
          :ayla-skills="vaultAdd.state.value.suggestedSkills"
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
            :disabled="isSaving"
            :aria-busy="isSaving"
            class="min-h-10 min-w-28.5 rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-60"
            @click="next"
          >
            {{ isSaving ? VAULT_ADD_SAVING : step === 'skills' ? VAULT_ADD_BUTTON : VAULT_ADD_NEXT }}
          </button>
        </div>
      </div>
    </div>

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
