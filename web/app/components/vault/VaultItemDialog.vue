<script setup lang="ts">
import type { VaultFile } from '~/types/vault';

// Everything about one item (iOS VaultItemDetailView): where it comes from, whether it is confirmed, the folders it is
// in and its documents. Changing it (details, folders, logo, cover, files, skills, Ayla) happens in "Aanpassen".
const props = defineProps<{
  itemId: string | null;
}>();

const emit = defineEmits<{
  close: [];
  edit: [itemId: string];
  requestConfirmation: [itemId: string];
}>();

const vault = useVault();
const supabase = useUntypedSupabase();
const deleteRef = useTemplateRef<{ open: () => void }>('confirmDelete');
const fileProblem = ref<string | null>(null);

const item = computed(() => vault.state.value.items.find((entry) => entry.id === props.itemId) ?? null);
const isOpen = computed({
  get: () => item.value !== null,
  set: (open) => {
    if (!open) emit('close');
  },
});
const folderNames = computed(() =>
  vault.state.value.folders.filter((folder) => item.value?.folderIds.includes(folder.id)).map((folder) => folder.name),
);
const place = computed(() => (item.value ? itemPlace(item.value) : null));
const period = computed(() => (item.value ? itemPeriod(item.value) : null));
// The logo and cover are pictures of the card, not evidence, so they are left out of "Bestanden".
const documents = computed(() => item.value?.files.filter((file) => file.role === 'document') ?? []);

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

watch(() => props.itemId, () => (fileProblem.value = null));
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
        <div class="flex flex-col gap-3.5 rounded-2xl border border-card-border bg-white p-4">
          <p class="text-sm font-medium text-heading">{{ VAULT_STATUS_EXPLANATIONS[item.status] }}</p>
          <!-- Also after a change: a confirmed item that was changed is Niet bevestigd again and can be sent anew. -->
          <button
            v-if="item.status !== 'verified'"
            type="button"
            class="flex min-h-13.25 w-full items-center justify-center gap-2.5 rounded-full border-[1.5px] border-brand bg-white px-4 text-base font-semibold text-brand transition-transform hover:bg-drop active:scale-[0.98] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            @click="emit('requestConfirmation', item.id)"
          >
            <VaultIcon src="/images/vault/icons/CheckBadgeSolid.svg" class="size-5" />
            {{ item.status === 'rejected' ? VAULT_REQUEST_AGAIN_ACTION : VAULT_REQUEST_ACTION }}
          </button>
        </div>
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
          <li v-if="folderNames.length" class="flex items-center gap-2.5">
            <VaultIcon src="/images/vault/icons/FolderSolid.svg" class="size-5" />{{ inFolders(folderNames) }}
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

      <section v-if="documents.length" class="flex flex-col gap-2.5">
        <h3 class="text-xs font-semibold text-subtle">{{ VAULT_DETAIL_FILES }}</h3>
        <ul class="flex flex-col gap-1 rounded-2xl border border-card-border bg-white p-2">
          <li v-for="file in documents" :key="file.id">
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
