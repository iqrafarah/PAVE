<script setup lang="ts">
import type { VaultAddStep, VaultCoverChoice, VaultItemDraft } from '~/types/vault';
import type { DraftField } from '~/utils/vaultAdd';

// "Kluis aanvullen" (Figma FEDDIES 1167:12715 → 1167:11759 → 1167:12237 → 1167:11255 → 1167:10880). Nothing is saved
// until the skills step: then the item, its files and its skills go into the vault at once, and the last card asks
// whether Ayla may use it. Closing halfway asks first, so nothing you filled in disappears by accident.
const vaultAdd = useVaultAdd();

const STEP_INDEX: Record<VaultAddStep, number> = { basis: 0, details: 1, cover: 1, skills: 2, done: 3 };

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const contentRef = useTemplateRef<HTMLDivElement>('content');
const detailsRef = useTemplateRef<{ focusFirstProblem: (field: DraftField) => void }>('details');
const discardRef = useTemplateRef<{ open: () => void }>('discard');
const titleId = useId();

const step = ref<VaultAddStep>('basis');
const file = ref<File | null>(null);
const draft = ref<VaultItemDraft>(createDraft());
const showsProblems = ref(false);
const coverChoice = ref<VaultCoverChoice>('none');
const cover = ref<File | null>(null);
const logo = ref<File | null>(null);
const coverProblem = ref<string | undefined>();
const skills = ref<string[]>([]);
const vaultSkills = ref<string[]>([]);
const isLoadingSkills = ref(false);
const isSaving = ref(false);
const saveError = ref<string | null>(null);
const itemId = ref<string | null>(null);
const allowsAyla = ref(false);

const stepIndex = computed(() => STEP_INDEX[step.value]);
const isDone = computed(() => step.value === 'done');
const problems = computed(() => (showsProblems.value ? checkDraft(draft.value) : {}));
const isDirty = computed(
  () =>
    Boolean(file.value || cover.value || logo.value || skills.value.length) ||
    Object.values(draft.value).some((value) => String(value).trim() !== ''),
);

function reset() {
  step.value = 'basis';
  file.value = null;
  draft.value = createDraft();
  showsProblems.value = false;
  coverChoice.value = 'none';
  cover.value = null;
  logo.value = null;
  coverProblem.value = undefined;
  skills.value = [];
  saveError.value = null;
  itemId.value = null;
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

function pickFile(picked: File) {
  file.value = picked;
  if (!draft.value.category && vaultAdd.state.value.category) draft.value.category = vaultAdd.state.value.category;
  goTo('details');
}

function addWithoutFile() {
  file.value = null;
  if (!draft.value.category) draft.value.category = vaultAdd.state.value.category ?? 'workExperience';
  goTo('details');
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
  if (coverChoice.value === 'cover' && !cover.value) {
    coverProblem.value = VAULT_PROBLEM_COVER;
    return;
  }
  coverProblem.value = undefined;
  goTo('skills');
}

async function saveItem() {
  isSaving.value = true;
  saveError.value = null;
  const result = await vaultAdd.save({
    draft: draft.value,
    file: file.value,
    cover: coverChoice.value === 'cover' ? cover.value : null,
    logo: logo.value,
    skills: skills.value,
  });
  isSaving.value = false;
  if (result.error !== null) {
    saveError.value = result.error;
    return;
  }
  itemId.value = result.itemId;
  goTo('done');
}

function next() {
  if (step.value === 'basis') {
    if (file.value) goTo('details');
    else saveError.value = VAULT_PROBLEM_FILE;
  }
  else if (step.value === 'details') checkDetails();
  else if (step.value === 'cover') checkCover();
  else if (step.value === 'skills') saveItem();
}

function back() {
  if (step.value === 'details') goTo('basis');
  else if (step.value === 'cover') goTo('details');
  else if (step.value === 'skills') goTo('cover');
}

async function finish() {
  if (allowsAyla.value && itemId.value) {
    isSaving.value = true;
    saveError.value = await vaultAdd.allowAyla(itemId.value);
    isSaving.value = false;
    if (saveError.value) return;
  }
  vaultAdd.close();
}

/** ✕, Escape or a click next to the card. Once saved it simply closes; halfway it asks first. */
function requestClose() {
  if (isSaving.value) return;
  if (!isDone.value && isDirty.value) discardRef.value?.open();
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
    :class="isDone ? 'max-w-108.25 rounded-done' : 'max-w-154 rounded-modal'"
    class="m-auto max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] overflow-hidden bg-white p-0 text-heading shadow-modal backdrop:bg-backdrop"
    @cancel="handleCancel"
    @close="handleClose"
    @click="handleBackdropClick"
  >
    <VaultAddDone
      v-if="isDone"
      v-model:allows-ayla="allowsAyla"
      :title-id="titleId"
      :is-saving="isSaving"
      :problem="saveError"
      @finish="finish"
    />

    <div v-else class="flex max-h-[calc(100dvh-2rem)] flex-col">
      <div class="flex items-start justify-between gap-4 px-9 pt-8.75 max-sm:px-5 sm:pr-11.5">
        <h2 :id="titleId" class="font-heading text-hero font-semibold text-heading max-sm:text-2xl">{{ VAULT_ADD_TITLE }}</h2>
        <button
          type="button"
          :aria-label="VAULT_ADD_CLOSE"
          :title="VAULT_ADD_CLOSE"
          class="mt-0.75 flex h-9.25 w-8.75 shrink-0 items-center justify-center rounded-field border border-field-line hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="requestClose"
        >
          <img src="/images/vault/close.svg" alt="" width="13.6909" height="13.6909" />
        </button>
      </div>

      <VaultAddSteps class="mx-9 mt-10 max-sm:mx-5 sm:mr-11.5" :current="stepIndex" />

      <div
        ref="content"
        tabindex="-1"
        autofocus
        :aria-label="`${VAULT_ADD_STEPS[stepIndex]} (${stepIndex + 1}/${VAULT_ADD_STEPS.length})`"
        class="min-h-0 flex-1 overflow-y-auto px-9 pb-1 pt-7.5 focus:outline-none max-sm:px-5"
      >
        <VaultBasisStep
          v-if="step === 'basis'"
          :file="file"
          @pick="pickFile"
          @remove-file="file = null"
          @without-file="addWithoutFile"
        />
        <VaultDetailsStep
          v-else-if="step === 'details'"
          ref="details"
          v-model:draft="draft"
          v-model:folder-id="vaultAdd.state.value.folderId"
          :file="file"
          :problems="problems"
          shows-folder
          @remove-file="file = null"
        />
        <VaultCoverStep
          v-else-if="step === 'cover'"
          v-model:choice="coverChoice"
          v-model:cover="cover"
          v-model:logo="logo"
          :problem="coverProblem"
        />
        <VaultSkillsStep
          v-else
          v-model:selected="skills"
          :vault-skills="vaultSkills"
          :ayla-skills="vaultAdd.state.value.suggestedSkills"
          :is-loading="isLoadingSkills"
        />
      </div>

      <div class="px-9 pb-8 pt-7 max-sm:px-5 sm:pr-10">
        <p v-if="saveError" role="alert" class="mb-3 text-sm text-danger">{{ saveError }}</p>
        <div class="flex justify-end gap-2.5">
          <button
            v-if="step !== 'basis'"
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
            {{ isSaving ? VAULT_ADD_SAVING : VAULT_ADD_NEXT }}
          </button>
        </div>
      </div>
    </div>

    <LayoutConfirmSheet ref="discard" :title="VAULT_DISCARD_TITLE" :confirm-label="VAULT_DISCARD_CONFIRM" @confirm="vaultAdd.close()" />
  </dialog>
</template>
