<script setup lang="ts">
import type { VaultFile, VaultFileRole } from '~/types/vault';

// Everything about one item (iOS VaultItemDetailView): where it comes from, whether it is confirmed and what you can
// do with it: change it (and the folder it is in), give the card a logo or cover, or delete it.
const props = defineProps<{
  itemId: string | null;
}>();

const emit = defineEmits<{
  close: [];
  edit: [itemId: string];
}>();

const vault = useVault();
const supabase = useUntypedSupabase();
const deleteRef = useTemplateRef<{ open: () => void }>('confirmDelete');
const fileProblem = ref<string | null>(null);
const imageInputRef = useTemplateRef<HTMLInputElement>('imageInput');
const imageRole = ref<Exclude<VaultFileRole, 'evidence'>>('logo');
const busyRole = ref<Exclude<VaultFileRole, 'evidence'> | null>(null);
const imageProblem = ref<string | null>(null);

const item = computed(() => vault.state.value.items.find((entry) => entry.id === props.itemId) ?? null);
const isOpen = computed({
  get: () => item.value !== null,
  set: (open) => {
    if (!open) emit('close');
  },
});
const folder = computed(() => (item.value ? vault.folder(item.value.folderId) : null));
const place = computed(() => (item.value ? itemPlace(item.value) : null));
const period = computed(() => (item.value ? itemPeriod(item.value) : null));
const imageButton =
  'min-h-8 rounded-lg px-2.5 text-sm font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-50';

// The logo and cover are pictures of the card, not evidence, so they are left out of "Bestanden".
const evidenceFiles = computed(() => item.value?.files.filter((file) => file.role === 'evidence') ?? []);
const hasOwnLogo = computed(() => item.value?.files.some((file) => file.role === 'logo') ?? false);
// An organisation's logo always wins, so then there is nothing to choose.
const hasOrganisationLogo = computed(() => Boolean(item.value?.logoUrl) && !hasOwnLogo.value);
const hasOwnCover = computed(() => item.value?.files.some((file) => file.role === 'cover') ?? false);

function pickImage(role: Exclude<VaultFileRole, 'evidence'>) {
  imageRole.value = role;
  imageProblem.value = null;
  imageInputRef.value?.click();
}

async function setImage(role: Exclude<VaultFileRole, 'evidence'>, file: File | null) {
  if (!item.value) return;
  if (file) {
    const problem = checkVaultFile(file, 'cover');
    if (problem) {
      imageProblem.value = problem;
      return;
    }
  }
  busyRole.value = role;
  const isSaved = await vault.setImage(item.value, role, file);
  busyRole.value = null;
  if (!isSaved) {
    imageProblem.value = vault.state.value.problem;
    vault.state.value.problem = null;
  }
}

function handleImage(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0] ?? null;
  input.value = '';
  if (file) setImage(imageRole.value, file);
}

async function remove() {
  if (!item.value) return;
  const removed = item.value;
  emit('close');
  await vault.remove(removed);
}

/** Opens a file in a new tab through a link that works for one minute; the bucket itself is private. */
async function openFile(file: VaultFile) {
  fileProblem.value = null;
  const { data, error } = await supabase.storage.from('pave-vault').createSignedUrl(file.storagePath, 60);
  if (error || !data) {
    fileProblem.value = VAULT_ERROR_GENERIC;
    return;
  }
  window.open(data.signedUrl, '_blank', 'noopener');
}

watch(
  () => props.itemId,
  () => {
    fileProblem.value = null;
    imageProblem.value = null;
  },
);
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="item ? VAULT_CATEGORY_TITLES[item.category] : ''">
    <div v-if="item" class="flex flex-col gap-5">
      <img v-if="item.coverUrl" :src="item.coverUrl" alt="" class="h-40 w-full rounded-2xl object-cover" />
      <div class="flex items-start gap-3.5">
        <VaultLogo :name="item.organisationName ?? item.title" :logo-url="item.logoUrl" :size="56" />
        <div class="flex min-w-0 flex-1 flex-col items-start gap-2">
          <p class="font-heading text-xl font-semibold text-heading">{{ item.title }}</p>
          <VaultStatusBadge :status="item.status" />
        </div>
      </div>

      <section class="flex flex-col gap-2.5">
        <h3 class="text-xs font-semibold text-subtle">{{ VAULT_DETAIL_STATUS }}</h3>
        <p class="rounded-2xl border border-card-border bg-white p-4 text-sm font-medium text-heading">
          {{ VAULT_STATUS_EXPLANATIONS[item.status] }}
        </p>
      </section>

      <section class="flex flex-col gap-2.5">
        <h3 class="text-xs font-semibold text-subtle">{{ VAULT_DETAIL_DATA }}</h3>
        <ul class="flex flex-col gap-3 rounded-2xl border border-card-border bg-white p-4 text-sm font-medium text-heading">
          <li v-if="place" class="flex items-center gap-2.5">
            <VaultIcon src="/images/vault/building.svg" class="size-5" />{{ place }}
          </li>
          <li v-if="period" class="flex items-center gap-2.5">
            <VaultIcon src="/images/vault/calendar.svg" class="size-5" />{{ period }}
          </li>
          <li v-if="folder" class="flex items-center gap-2.5">
            <VaultIcon src="/images/vault/icons/FolderSolid.svg" class="size-5" />{{ VAULT_DETAIL_IN_FOLDER(folder.name) }}
          </li>
          <li class="flex items-center gap-2.5">
            <VaultIcon src="/images/vault/icons/InformationCircle.svg" class="size-5" />
            {{ VAULT_SOURCE_TITLES[item.source] }}, {{ fullDay(item.createdAt.slice(0, 10)) }}
          </li>
        </ul>
      </section>

      <section v-if="item.description" class="flex flex-col gap-2.5">
        <h3 class="text-xs font-semibold text-subtle">{{ VAULT_DETAIL_DESCRIPTION }}</h3>
        <p class="whitespace-pre-wrap rounded-2xl border border-card-border bg-white p-4 text-sm font-medium text-heading">
          {{ item.description }}
        </p>
      </section>

      <section v-if="item.skills.length" class="flex flex-col gap-2.5">
        <h3 class="text-xs font-semibold text-subtle">{{ VAULT_DETAIL_SKILLS }}</h3>
        <ul class="flex flex-wrap gap-1.5 rounded-2xl border border-card-border bg-white p-4">
          <li v-for="skill in item.skills" :key="skill"><VaultSkillChip :text="skill" /></li>
        </ul>
      </section>

      <!-- The card: a round logo and a cover picture on top, both optional and yours to change. -->
      <section class="flex flex-col gap-2.5" :aria-busy="busyRole !== null">
        <h3 class="text-xs font-semibold text-subtle">{{ VAULT_DETAIL_CARD }}</h3>
        <input ref="imageInput" type="file" :accept="VAULT_COVER_ACCEPT" class="sr-only" tabindex="-1" aria-hidden="true" @change="handleImage" />
        <ul class="flex flex-col divide-y divide-card-border rounded-2xl border border-card-border bg-white">
          <li class="flex items-center gap-3 p-3">
            <VaultLogo :name="item.organisationName ?? item.title" :logo-url="item.logoUrl" :size="40" />
            <span class="min-w-0 flex-1 text-sm font-medium text-heading">{{ VAULT_LOGO }}</span>
            <span v-if="hasOrganisationLogo" class="text-xs text-subtle">{{ VAULT_LOGO_FROM_ORGANISATION }}</span>
            <button v-else type="button" :class="imageButton" :disabled="busyRole !== null" @click="pickImage('logo')">
              {{ busyRole === 'logo' ? VAULT_SAVING : hasOwnLogo ? VAULT_IMAGE_CHANGE : VAULT_IMAGE_CHOOSE }}
            </button>
            <button v-if="hasOwnLogo" type="button" :class="imageButton" class="text-danger" :disabled="busyRole !== null" @click="setImage('logo', null)">
              {{ VAULT_DELETE }}
            </button>
          </li>
          <li class="flex items-center gap-3 p-3">
            <span class="flex h-10 w-14 shrink-0 overflow-hidden rounded-lg bg-tile" aria-hidden="true">
              <img v-if="item.coverUrl" :src="item.coverUrl" alt="" class="size-full object-cover" />
            </span>
            <span class="min-w-0 flex-1 text-sm font-medium text-heading">{{ VAULT_COVER }}</span>
            <button type="button" :class="imageButton" :disabled="busyRole !== null" @click="pickImage('cover')">
              {{ busyRole === 'cover' ? VAULT_SAVING : item.coverUrl ? VAULT_IMAGE_CHANGE : VAULT_IMAGE_CHOOSE }}
            </button>
            <button v-if="hasOwnCover" type="button" :class="imageButton" class="text-danger" :disabled="busyRole !== null" @click="setImage('cover', null)">
              {{ VAULT_DELETE }}
            </button>
          </li>
        </ul>
        <p v-if="imageProblem" role="alert" class="text-xs text-danger">{{ imageProblem }}</p>
      </section>

      <section v-if="evidenceFiles.length" class="flex flex-col gap-2.5">
        <h3 class="text-xs font-semibold text-subtle">{{ VAULT_DETAIL_FILES }}</h3>
        <ul class="flex flex-col gap-1 rounded-2xl border border-card-border bg-white p-2">
          <li v-for="file in evidenceFiles" :key="file.id">
            <button
              type="button"
              class="flex w-full items-center gap-2.5 rounded-lg px-2 py-2 text-left text-sm font-medium text-heading hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
              @click="openFile(file)"
            >
              <VaultIcon src="/images/vault/icons/DocumentSolid.svg" class="size-5 text-brand" />
              <span class="min-w-0 flex-1 truncate">{{ file.name }}</span>
            </button>
          </li>
        </ul>
        <p v-if="fileProblem" role="alert" class="text-xs text-danger">{{ fileProblem }}</p>
      </section>

    </div>

    <template #footer>
      <button
        type="button"
        class="mr-auto min-h-10 rounded-field px-3 text-base font-medium text-danger hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="deleteRef?.open()"
      >
        {{ VAULT_DELETE }}
      </button>
      <button
        v-if="item"
        type="button"
        class="min-h-10 min-w-25.75 rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('edit', item.id)"
      >
        {{ VAULT_EDIT }}
      </button>
      <button
        type="button"
        class="min-h-10 min-w-25.75 rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('close')"
      >
        {{ VAULT_DETAIL_DONE }}
      </button>
    </template>

    <LayoutConfirmSheet
      ref="confirmDelete"
      :title="VAULT_DELETE_TITLE"
      :message="VAULT_DELETE_MESSAGE"
      :confirm-label="VAULT_DELETE"
      @confirm="remove"
    />
  </VaultSheet>
</template>
