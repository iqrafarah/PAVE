<script setup lang="ts">
// The row under the home composer (Figma Start): an item from the vault, a plan, or a file.
const emit = defineEmits<{
  addFile: [];
  pickItem: [];
  pickPlan: [];
}>();

const ACTIONS = [
  { id: 'item', label: AYLA_ADD_ITEM_LABEL, icon: '/images/ayla/add-item.svg', width: 18, height: 16 },
  { id: 'plan', label: AYLA_ADD_PLAN_LABEL, icon: '/images/ayla/add-plan.svg', width: 17, height: 16 },
  { id: 'file', label: AYLA_ADD_FILE_LABEL, icon: '/images/ayla/add-file.svg', width: 14.6, height: 15.6 },
] as const;

function choose(id: (typeof ACTIONS)[number]['id']) {
  if (id === 'item') emit('pickItem');
  else if (id === 'plan') emit('pickPlan');
  else emit('addFile');
}
</script>

<template>
  <div class="flex items-center justify-center gap-5.25 text-xs font-medium text-heading">
    <button
      v-for="action in ACTIONS"
      :key="action.id"
      type="button"
      class="inline-flex items-center gap-2 rounded-md hover:text-brand focus-visible:outline-2 focus-visible:outline-brand"
      @click="choose(action.id)"
    >
      <VaultIcon :src="action.icon" class="text-brand" :width="action.width" :height="action.height" />
      <span class="whitespace-nowrap max-sm:sr-only">{{ action.label }}</span>
    </button>
  </div>
</template>
