<script setup lang="ts">
// The row under the home composer (Figma Start). The vault and the plan are not built on the web yet.
const emit = defineEmits<{
  addFile: [];
}>();

const LATER_ACTIONS = [
  { label: AYLA_ADD_ITEM_LABEL, icon: '/images/ayla/add-item.svg', width: 18, height: 16 },
  { label: AYLA_ADD_PLAN_LABEL, icon: '/images/ayla/add-plan.svg', width: 17, height: 16 },
];
</script>

<template>
  <div class="flex items-center justify-center gap-5.25 text-xs font-medium text-heading">
    <button
      v-for="action in LATER_ACTIONS"
      :key="action.label"
      type="button"
      disabled
      :title="AYLA_NOT_AVAILABLE_YET"
      class="inline-flex cursor-not-allowed items-center gap-2"
    >
      <img :src="action.icon" alt="" :width="action.width" :height="action.height" />
      <span class="whitespace-nowrap max-sm:sr-only">{{ action.label }}</span>
      <span class="sr-only">({{ AYLA_NOT_AVAILABLE_YET }})</span>
    </button>
    <button
      type="button"
      class="inline-flex items-center gap-2 rounded-md hover:text-brand focus-visible:outline-2 focus-visible:outline-brand"
      @click="emit('addFile')"
    >
      <img src="/images/ayla/add-file.svg" alt="" width="14.6" height="15.6" />
      <span class="whitespace-nowrap max-sm:sr-only">{{ AYLA_ADD_FILE_LABEL }}</span>
    </button>
  </div>
</template>
