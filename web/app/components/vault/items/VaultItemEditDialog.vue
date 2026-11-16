<script setup lang="ts">
import type { VaultFile, VaultItemDraft } from '~/types/vault';
import type { DraftField } from '~/utils/vault/vaultAdd';

// "Bewijs aanpassen" (iOS VaultEvidenceEditor): one page with the details and folders, the logo and cover, the
// documents, the skills and Ayla's permission. Every item can be changed; a confirmed one says up front that a change
// means it has to be confirmed again, and asks once more before saving. Closing with changes asks first.
const props = defineProps<{
  itemId: string | null;
}>();

const emit = defineEmits<{
  close: [];
}>();

const vault = useVault();
const vaultAdd = useVaultAdd();
const supabase = useUntypedSupabase();
const detailsRef = useTemplateRef<{ focusFirstProblem: (field: DraftField) => void }>('details');
const discardRef = useTemplateRef<{ open: () => void }>('discard');
const reconfirmRef = useTemplateRef<{ open: () => void }>('reconfirm');

const draft = ref<VaultItemDraft>(createDraft());
const initialDraft = ref<VaultItemDraft>(createDraft());
const folderIds = ref<string[]>([]);
const removedFiles = ref<VaultFile[]>([]);
const newDocuments = ref<File[]>([]);
const newLogo = ref<File | null>(null);
const newCover = ref<File | null>(null);
const removesLogo = ref(false);
const wantsCover = ref(false);
const skills = ref<string[]>([]);
const vaultSkills = ref<string[]>([]);
const isLoadingSkills = ref(false);
const allowsAyla = ref(false);
const showsProblems = ref(false);
const isSaving = ref(false);
const saveError = ref<string | null>(null);

const item = computed(() => vault.state.value.items.find((entry) => entry.id === props.itemId) ?? null);
const problems = computed(() => (showsProblems.value ? checkDraft(draft.value) : {}));

const savedLogo = computed(() => item.value?.files.find((file) => file.role === 'logo') ?? null);
const savedCover = computed(() => item.value?.files.find((file) => file.role === 'cover') ?? null);
const keptDocuments = computed(
  () => item.value?.files.filter((file) => file.role === 'document' && !removedFiles.value.includes(file)) ?? [],
);
const newLogoUrl = useObjectUrl(newLogo);
const newCoverUrl = useObjectUrl(newCover);
// The organisation's logo is on the card no matter what you add (its link is not one of your files).
const hasOrganisationLogo = computed(() => Boolean(item.value?.logoUrl) && !savedLogo.value && item.value?.coverUrl !== item.value?.logoUrl);
const shownLogoUrl = computed(() => {
  if (newLogoUrl.value) return newLogoUrl.value;
  // Without a logo the circle shows the cover, as on the card.
  if (removesLogo.value || !savedLogo.value) return hasOrganisationLogo.value ? item.value!.logoUrl : shownCoverUrl.value;
  return item.value?.logoUrl ?? null;
});
const shownCoverUrl = computed(() => newCoverUrl.value ?? (savedCover.value && wantsCover.value ? item.value?.coverUrl ?? null : null));
const removesCover = computed(() => Boolean(savedCover.value) && (!wantsCover.value || Boolean(newCover.value)));

const detailsChanged = computed(() => JSON.stringify(draft.value) !== JSON.stringify(initialDraft.value));
const foldersChanged = computed(() => [...folderIds.value].sort().join() !== [...(item.value?.folderIds ?? [])].sort().join());
const filesChanged = computed(
  () => Boolean(removedFiles.value.length || newDocuments.value.length || newLogo.value || newCover.value || removesLogo.value || removesCover.value),
);
const skillsChanged = computed(() => [...skills.value].sort().join('|') !== [...(item.value?.skills ?? [])].sort().join('|'));
const consentChanged = computed(() => allowsAyla.value !== Boolean(item.value?.aylaAllowedAt));
const hasChanges = computed(
  () => detailsChanged.value || foldersChanged.value || filesChanged.value || skillsChanged.value || consentChanged.value,
);
// Only the details and the files count as changing the evidence itself (the database resets the status for those).
const needsConfirming = computed(() => Boolean(item.value && needsReconfirmation(item.value)) && (detailsChanged.value || filesChanged.value));

const isOpen = computed({
  get: () => item.value !== null,
  set: (open) => {
    if (open) return;
    if (isSaving.value) return;
    if (hasChanges.value) discardRef.value?.open();
    else emit('close');
  },
});

watch(
  item,
  async (current, previous) => {
    if (!current || current.id === previous?.id) return;
    const loaded: VaultItemDraft = {
      title: current.title,
      category: current.category,
      organisationName: current.organisationName ?? '',
      startMonth: current.startDate?.slice(0, 7) ?? '',
      endMonth: current.isCurrent ? '' : (current.endDate?.slice(0, 7) ?? ''),
      issuedMonth: current.issuedOn?.slice(0, 7) ?? '',
      description: current.description ?? '',
      usesPeriod: current.startDate ? true : current.issuedOn ? false : null,
    };
    draft.value = { ...loaded };
    initialDraft.value = { ...loaded };
    folderIds.value = [...current.folderIds];
    removedFiles.value = [];
    newDocuments.value = [];
    newLogo.value = null;
    newCover.value = null;
    removesLogo.value = false;
    wantsCover.value = current.files.some((file) => file.role === 'cover');
    skills.value = [...current.skills];
    allowsAyla.value = Boolean(current.aylaAllowedAt);
    showsProblems.value = false;
    saveError.value = null;
    isLoadingSkills.value = true;
    vaultSkills.value = await vaultAdd.loadVaultSkills();
    isLoadingSkills.value = false;
  },
  { immediate: true },
);

function pickImage(role: 'logo' | 'cover', file: File) {
  if (role === 'logo') {
    newLogo.value = file;
    removesLogo.value = false;
  } else newCover.value = file;
}

function removeImage(role: 'logo' | 'cover') {
  if (role === 'logo') {
    newLogo.value = null;
    removesLogo.value = Boolean(savedLogo.value);
  } else {
    newCover.value = null;
    wantsCover.value = false;
  }
}

/**
 * What Ayla may look at for her skill proposal: the files added just now, and the saved ones only while "Ayla mag dit
 * bekijken en gebruiken" is on. Without that permission she never opens what is already in the vault.
 */
async function documentsForAyla(): Promise<File[]> {
  if (!allowsAyla.value) return newDocuments.value;
  const saved = await Promise.all(
    keptDocuments.value.map(async (file) => {
      const { data } = await supabase.storage.from('pave-vault').download(file.storagePath);
      return data ? new File([data], file.name, { type: file.mimeType ?? data.type }) : null;
    }),
  );
  return [...saved.filter((file): file is File => file !== null), ...newDocuments.value];
}

function pickDocument(file: File) {
  if (keptDocuments.value.length + newDocuments.value.length >= MAX_DOCUMENTS) return;
  newDocuments.value = [...newDocuments.value, file];
}

/** Bewaren: checks the form, and for a confirmed item asks first whether it may be confirmed again. */
function requestSave() {
  showsProblems.value = true;
  const missing = Object.keys(checkDraft(draft.value)) as DraftField[];
  if (missing.length) {
    detailsRef.value?.focusFirstProblem(missing[0]!);
    return;
  }
  if (needsConfirming.value) reconfirmRef.value?.open();
  else save();
}

async function save() {
  const current = item.value;
  if (!current) return;
  isSaving.value = true;
  saveError.value = null;
  try {
    // The details only when they changed: saving them sets a confirmed item back to "Niet bevestigd".
    if (detailsChanged.value) await vault.saveDetails(current.id, draft.value, folderIds.value);
    else if (foldersChanged.value) await vault.saveFolders(current.id, folderIds.value);
    for (const file of removedFiles.value) await vault.removeFile(file);
    for (const file of newDocuments.value) await vault.attach(current.id, file, 'document');
    if (savedLogo.value && (removesLogo.value || newLogo.value)) await vault.removeFile(savedLogo.value);
    if (newLogo.value) await vault.attach(current.id, newLogo.value, 'logo');
    if (savedCover.value && removesCover.value) await vault.removeFile(savedCover.value);
    if (wantsCover.value && newCover.value) await vault.attach(current.id, newCover.value, 'cover');
    const added = skills.value.filter((name) => !current.skills.some((skill) => skill.toLowerCase() === name.toLowerCase()));
    const removed = current.skills.filter((name) => !skills.value.some((skill) => skill.toLowerCase() === name.toLowerCase()));
    await vault.addSkills(current.id, added);
    await vault.removeSkills(current.id, removed);
    if (consentChanged.value) await vault.setAylaAllowed(current.id, allowsAyla.value);
  } catch (error) {
    saveError.value = error instanceof VaultSaveError ? error.message : VAULT_ERROR_GENERIC;
    isSaving.value = false;
    // What did work is in the vault; reading it again keeps the form honest about what is saved.
    await vault.load();
    return;
  }
  await vault.load();
  isSaving.value = false;
  emit('close');
}
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="VAULT_EDIT_TITLE">
    <div v-if="item" class="flex flex-col gap-9" :aria-busy="isSaving">
      <div class="flex flex-col gap-3">
        <VaultStatusBadge :status="item.status" class="self-start" />
        <div v-if="needsReconfirmation(item)" class="rounded-2xl bg-status-pending-surface p-4 text-sm text-heading">
          <p class="font-semibold">{{ VAULT_RECONFIRM_TITLE }}</p>
          <p class="mt-1">{{ VAULT_RECONFIRM_MESSAGE }}</p>
        </div>
      </div>

      <VaultDetailsStep
        ref="details"
        v-model:draft="draft"
        v-model:folder-ids="folderIds"
        :problems="problems"
      />

      <VaultLookSection
        v-model:wants-cover="wantsCover"
        :logo-url="shownLogoUrl"
        :cover-url="shownCoverUrl"
        :title="draft.title"
        :organisation-name="draft.organisationName"
        :category="draft.category"
        :has-organisation-logo="hasOrganisationLogo"
        :has-logo="Boolean(newLogo || (savedLogo && !removesLogo))"
        @pick="pickImage"
        @remove="removeImage"
      />

      <VaultDocumentsSection
        :saved="keptDocuments"
        :files="newDocuments"
        @pick="pickDocument"
        @remove-saved="removedFiles = [...removedFiles, $event]"
        @remove-file="newDocuments = newDocuments.filter((_, index) => index !== $event)"
      />

      <VaultSkillsStep
        v-model:selected="skills"
        :vault-skills="vaultSkills"
        :is-loading="isLoadingSkills"
        :draft="draft"
        :load-documents="documentsForAyla"
      />

      <label
        :class="allowsAyla ? 'border-brand/40 bg-drop' : 'border-field-line bg-white'"
        class="flex cursor-pointer items-start gap-3.5 rounded-xl border p-3.5 has-focus-visible:outline-2 has-focus-visible:outline-brand"
      >
        <span class="flex size-9 shrink-0 items-center justify-center rounded-[0.5625rem] bg-brand" aria-hidden="true">
          <AylaSlashIcon :blocks="4" class="h-4.25 w-2.75 text-white" />
        </span>
        <span class="flex min-w-0 flex-1 flex-col gap-1">
          <span class="text-sm font-semibold text-heading">{{ VAULT_CONSENT(item.files.some((file) => file.role === 'document')) }}</span>
          <span class="text-xs text-subtle">{{ VAULT_CONSENT_MEANING }}</span>
        </span>
        <input v-model="allowsAyla" type="checkbox" role="switch" class="peer sr-only" />
        <span
          class="relative mt-1 h-6 w-10 shrink-0 rounded-full bg-field-line transition-colors after:absolute after:left-0.5 after:top-0.5 after:size-5 after:rounded-full after:bg-white after:shadow after:transition-transform peer-checked:bg-brand peer-checked:after:translate-x-4"
          aria-hidden="true"
        />
      </label>
    </div>

    <template #footer>
      <p v-if="saveError" role="alert" class="w-full text-sm text-danger">{{ saveError }}</p>
      <button
        type="button"
        :disabled="isSaving"
        class="min-h-10 min-w-25.75 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="isOpen = false"
      >
        {{ VAULT_CANCEL }}
      </button>
      <button
        type="button"
        :disabled="isSaving || !hasChanges"
        class="min-h-10 min-w-28.5 rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
        @click="requestSave"
      >
        {{ isSaving ? VAULT_SAVING : VAULT_SAVE }}
      </button>
    </template>

    <LayoutConfirmSheet
      ref="discard"
      :title="VAULT_DISCARD_CHANGES_TITLE"
      :message="VAULT_DISCARD_CHANGES_MESSAGE"
      :confirm-label="VAULT_DISCARD_CHANGES_CONFIRM"
      :cancel-label="VAULT_DISCARD_CHANGES_KEEP"
      @confirm="emit('close')"
    />
    <LayoutConfirmSheet
      ref="reconfirm"
      :title="VAULT_RECONFIRM_QUESTION"
      :message="VAULT_RECONFIRM_MESSAGE"
      :confirm-label="VAULT_SAVE"
      is-calm
      @confirm="save"
    />
  </VaultSheet>
</template>
