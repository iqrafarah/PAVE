<script setup lang="ts">
// A picture or PDF of the vault shown over the page itself, with a button to download it. Other kinds (Word, text) cannot
// be shown by the browser: they say so and offer the download.
const preview = useFilePreview();
const vault = useVault();

const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const titleId = useId();
const address = ref<string | null>(null);
const status = ref<'loading' | 'ready' | 'failed'>('loading');
const downloadFailed = ref(false);

const file = computed(() => preview.file.value);
const kind = computed(() => {
  const current = file.value;
  if (!current) return 'other';
  if (current.mimeType.startsWith('image/') || ['jpg', 'jpeg', 'png', 'heic', 'gif', 'webp'].includes(getExtension(current.name))) return 'image';
  if (current.mimeType === 'application/pdf' || getExtension(current.name) === 'pdf') return 'pdf';
  return 'other';
});

function release() {
  if (address.value) URL.revokeObjectURL(address.value);
  address.value = null;
}

watch(
  file,
  async (current) => {
    release();
    downloadFailed.value = false;
    if (!current) {
      if (dialogRef.value?.open) dialogRef.value.close();
      return;
    }
    status.value = kind.value === 'other' ? 'ready' : 'loading';
    await nextTick();
    if (!dialogRef.value?.open) dialogRef.value?.showModal();
    if (kind.value === 'other') return;
    const url = await vault.readFile(current);
    // Closed or replaced while it was loading: the address is no longer wanted.
    if (file.value !== current) {
      if (url) URL.revokeObjectURL(url);
      return;
    }
    address.value = url;
    status.value = url ? 'ready' : 'failed';
  },
  { flush: 'post' },
);

async function download() {
  if (!file.value) return;
  downloadFailed.value = !(await vault.downloadFile(file.value));
}

function backdropClick(event: MouseEvent) {
  if (event.target === dialogRef.value) preview.close();
}

onBeforeUnmount(release);
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    class="m-auto hidden h-[min(52rem,92vh)] w-[min(64rem,94vw)] flex-col overflow-hidden rounded-2xl border border-card-line bg-white p-0 shadow-modal open:flex backdrop:bg-ink/50 max-sm:h-full max-sm:w-full max-sm:max-w-none max-sm:rounded-none"
    @close="preview.close()"
    @click="backdropClick"
  >
    <div class="flex items-center gap-3 border-b border-card-line px-5 py-3">
      <h2 :id="titleId" class="min-w-0 flex-1 truncate text-base font-semibold text-heading">{{ file?.name }}</h2>
      <button
        type="button"
        class="h-9 shrink-0 rounded-lg px-3 text-sm font-medium text-brand hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="download"
      >
        {{ VAULT_FILE_DOWNLOAD }}
      </button>
      <button
        type="button"
        class="flex size-9 shrink-0 items-center justify-center rounded-lg text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
        @click="preview.close()"
      >
        <svg viewBox="0 0 12 12" class="size-3.5" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">
          <path d="M2 2l8 8M10 2L2 10" />
        </svg>
        <span class="sr-only">{{ VAULT_FILE_CLOSE }}</span>
      </button>
    </div>

    <p v-if="downloadFailed" role="alert" class="px-5 pt-2 text-sm text-danger">{{ VAULT_FILE_FAILED }}</p>

    <div class="flex min-h-0 flex-1 items-center justify-center bg-surface">
      <p v-if="status === 'loading'" role="status" class="text-sm text-subtle">{{ VAULT_FILE_LOADING }}</p>
      <p v-else-if="status === 'failed'" role="alert" class="px-6 text-center text-sm text-danger">{{ VAULT_FILE_FAILED }}</p>
      <img v-else-if="kind === 'image' && address" :src="address" :alt="file?.name" class="max-h-full max-w-full object-contain" />
      <iframe v-else-if="kind === 'pdf' && address" :src="address" :title="file?.name" class="size-full border-0" />
      <p v-else class="px-6 text-center text-sm text-subtle">{{ VAULT_FILE_NO_PREVIEW }}</p>
    </div>
  </dialog>
</template>
