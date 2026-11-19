<script setup lang="ts">
// Above the form Ayla filled in (iOS VaultAylaFilledBanner): check everything. When she saw more than one item, such as
// a certificate and a list of grades, one item stays the default and adding them apart is one tap away.
defineProps<{
  splitTitles: string[] | null;
}>();

const addsApart = defineModel<boolean>('addsApart', { required: true });
const groupId = useId();
</script>

<template>
  <div class="flex items-start gap-3.5 rounded-xl border border-drop-line bg-drop p-3.5">
    <span class="flex size-9 shrink-0 items-center justify-center rounded-[0.5625rem] bg-brand" aria-hidden="true">
      <AylaSlashIcon class="h-5 w-3 text-white!" />
    </span>
    <div class="flex min-w-0 flex-1 flex-col gap-1.5">
      <h3 class="text-sm font-semibold text-heading">{{ VAULT_AYLA_FILLED_TITLE }}</h3>
      <p class="text-xs font-medium text-subtle">{{ VAULT_AYLA_FILLED_MESSAGE }}</p>
      <div v-if="splitTitles?.length" class="mt-1.5 flex flex-col gap-2">
        <p :id="groupId" class="text-xs font-medium text-heading">{{ VAULT_AYLA_SPLIT_TITLE(splitTitles) }}</p>
        <div class="flex rounded-lg bg-badge/40 p-0.5" role="radiogroup" :aria-labelledby="groupId">
          <button
            v-for="option in [false, true]"
            :key="String(option)"
            type="button"
            role="radio"
            :aria-checked="addsApart === option"
            :class="addsApart === option ? 'bg-white text-heading shadow-sm' : 'text-subtle hover:text-heading'"
            class="h-8 flex-1 rounded-md px-3 text-xs font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-brand"
            @click="addsApart = option"
          >
            {{ option ? VAULT_AYLA_SPLIT_APART : VAULT_AYLA_SPLIT_ONE }}
          </button>
        </div>
        <p class="text-[0.6875rem] font-medium text-subtle" aria-live="polite">{{ VAULT_AYLA_SPLIT_HINT(addsApart, splitTitles[0]!) }}</p>
      </div>
    </div>
  </div>
</template>
