<script setup lang="ts">
// Step 4 (Figma 1167:10880): the evidence is in the vault. Ayla may only look at it if you tick the box; that can be
// taken back later in the vault.
defineProps<{
  titleId: string;
  isSaving: boolean;
  problem: string | null;
}>();

const emit = defineEmits<{
  finish: [];
}>();

const allowsAyla = defineModel<boolean>('allowsAyla', { required: true });
const consentId = useId();
const problemId = useId();
</script>

<template>
  <div class="flex flex-col items-center px-5.75 pb-5.75 pt-8.5 text-center">
    <h2 :id="titleId" class="font-heading text-hero font-semibold text-heading">{{ VAULT_DONE_TITLE }}</h2>
    <img src="/images/vault/success-check.svg" alt="" width="136" height="136" class="mt-8" />

    <div class="mt-12 flex items-center gap-3">
      <span class="relative flex size-3.75 shrink-0">
        <input
          :id="consentId"
          v-model="allowsAyla"
          type="checkbox"
          :aria-describedby="problem ? problemId : undefined"
          class="peer size-3.75 cursor-pointer appearance-none rounded-sm border-[1.3px] border-checkbox bg-white checked:border-brand checked:bg-brand focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        />
        <LayoutPaveIcon name="check" class="pointer-events-none absolute inset-0 hidden size-3.75 text-white peer-checked:block" />
      </span>
      <label :for="consentId" class="cursor-pointer text-left text-sm font-medium text-brand">{{ VAULT_DONE_CONSENT }}</label>
    </div>
    <p v-if="problem" :id="problemId" role="alert" class="mt-2 text-xs text-danger">{{ problem }}</p>

    <button
      type="button"
      :disabled="isSaving"
      class="mt-4.5 min-h-10.75 w-full rounded-lg bg-brand text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
      @click="emit('finish')"
    >
      {{ VAULT_DONE_FINISH }}
    </button>
  </div>
</template>
