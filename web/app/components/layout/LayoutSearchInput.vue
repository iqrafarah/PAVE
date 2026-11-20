<script setup lang="ts">
// A search field: the magnifier, what you type and a quiet round button to clear it (instead of the blue cross the
// browser draws itself). Escape clears first and only then lets go, so one press never loses more than it should.
defineProps<{
  placeholder: string;
  label: string;
}>();

const emit = defineEmits<{
  escape: [];
}>();

const model = defineModel<string>({ required: true });
const inputRef = useTemplateRef<HTMLInputElement>('input');
const id = useId();

function clear() {
  model.value = '';
  inputRef.value?.focus();
}

function handleEscape() {
  if (model.value) model.value = '';
  else emit('escape');
}

defineExpose({ focus: () => inputRef.value?.focus() });
</script>

<template>
  <div class="flex h-10 items-center gap-2.5 rounded-field border border-field-line bg-white pl-3 pr-1.5 focus-within:border-subtle">
    <LayoutPaveIcon name="search" class="size-4 shrink-0 text-brand" aria-hidden="true" />
    <label :for="id" class="sr-only">{{ label }}</label>
    <input
      :id="id"
      ref="input"
      v-model="model"
      type="search"
      autocomplete="off"
      :placeholder="placeholder"
      class="min-w-0 flex-1 appearance-none bg-transparent text-sm font-medium text-heading placeholder:text-subtle/50 focus:outline-none [&::-webkit-search-cancel-button]:hidden [&::-webkit-search-cancel-button]:appearance-none"
      @keydown.esc.stop="handleEscape"
    />
    <button
      v-if="model"
      type="button"
      class="flex size-6 shrink-0 items-center justify-center rounded-full bg-tint text-subtle hover:bg-brand-soft hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
      @click="clear"
    >
      <svg viewBox="0 0 12 12" class="size-2.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
        <path d="M2 2l8 8M10 2L2 10" />
      </svg>
      <span class="sr-only">{{ SEARCH_CLEAR }}</span>
    </button>
  </div>
</template>
