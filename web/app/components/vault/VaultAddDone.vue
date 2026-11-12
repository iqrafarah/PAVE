<script setup lang="ts">
// Step 4, "Toestemming" (iOS VaultEvidenceAddedView, Figma 1167:10880): the evidence is in the vault. The tick lands,
// then the card about Ayla rises in. It starts off: Ayla only takes the evidence along when you switch it on, and that
// can be taken back later in the vault.
defineProps<{
  titleId: string;
  isSaving: boolean;
  hasFile: boolean;
  problem: string | null;
  // The logo or cover could not be kept yet (the vault is not ready for them).
  notice?: string | null;
}>();

const emit = defineEmits<{
  finish: [];
}>();

const allowsAyla = defineModel<boolean>('allowsAyla', { required: true });
const meaningId = useId();
const problemId = useId();
const hasLanded = ref(false);

onMounted(() => requestAnimationFrame(() => (hasLanded.value = true)));
</script>

<template>
  <div class="flex flex-col items-center px-6 pb-6 pt-10 text-center">
    <span
      :class="hasLanded ? 'scale-100 opacity-100' : 'scale-50 opacity-0'"
      class="flex size-26 items-center justify-center rounded-full bg-brand text-white transition duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)] motion-reduce:transition-none"
      aria-hidden="true"
    >
      <LayoutPaveIcon name="check" class="size-11" />
    </span>
    <h2 :id="titleId" class="mt-5.5 font-heading text-2xl font-semibold text-heading">{{ VAULT_DONE_TITLE }}</h2>
    <p class="mt-2 max-w-85 text-sm font-medium text-subtle">{{ VAULT_DONE_MESSAGE }}</p>
    <p v-if="notice" class="mt-4 rounded-xl bg-status-pending-surface px-3.5 py-2.5 text-left text-xs font-medium text-status-pending">{{ notice }}</p>

    <label
      :class="[
        allowsAyla ? 'border-drop-line bg-drop' : 'border-field-line bg-white',
        hasLanded ? 'translate-y-0 opacity-100' : 'translate-y-4 opacity-0',
      ]"
      class="mt-8 flex w-full cursor-pointer items-start gap-3.5 rounded-xl border p-3.5 text-left transition delay-300 duration-500 has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand motion-reduce:transition-none"
    >
      <span class="flex size-9 shrink-0 items-center justify-center rounded-[0.5625rem] bg-brand" aria-hidden="true">
        <AylaSlashIcon class="h-5 w-3 text-white!" />
      </span>
      <span class="flex min-w-0 flex-1 flex-col gap-1">
        <span class="text-sm font-semibold text-heading">{{ VAULT_CONSENT(hasFile) }}</span>
        <span :id="meaningId" class="text-xs font-medium text-subtle">{{ VAULT_CONSENT_MEANING }}</span>
      </span>
      <span class="relative mt-0.5 flex h-7 w-12 shrink-0">
        <input v-model="allowsAyla" type="checkbox" role="switch" :aria-describedby="meaningId" class="peer sr-only" />
        <span class="absolute inset-0 rounded-full bg-badge transition-colors peer-checked:bg-brand" />
        <span class="absolute left-0.5 top-0.5 size-6 rounded-full bg-white shadow transition-transform peer-checked:translate-x-5 motion-reduce:transition-none" />
      </span>
    </label>
    <p v-if="problem" :id="problemId" role="alert" class="mt-2 text-xs text-danger">{{ problem }}</p>

    <button
      type="button"
      :disabled="isSaving"
      class="mt-4 min-h-11 w-full rounded-lg bg-brand text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
      @click="emit('finish')"
    >
      {{ VAULT_DONE_FINISH }}
    </button>
  </div>
</template>
