<script setup lang="ts">
import type { MemoryCategory } from '~/types/ayla';

// Writing a note yourself, or changing one (iOS AylaMemoryEditor, a sheet): "Annuleren", the title and "Bewaren" on
// top, the text with its footer, and the category as a list with a check. Opens as soon as it is shown.
const props = defineProps<{
  title: string;
  initialText: string;
  initialCategory: MemoryCategory;
}>();

const emit = defineEmits<{
  save: [text: string, category: MemoryCategory];
  close: [];
}>();

const text = ref(props.initialText);
const category = ref<MemoryCategory>(props.initialCategory);
const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const textareaRef = useTemplateRef<HTMLTextAreaElement>('textarea');
const titleId = useId();
const textId = useId();
const footerId = useId();

const canSave = computed(() => text.value.trim().length > 0);

function cancel() {
  dialogRef.value?.close();
}

function save() {
  if (!canSave.value) return;
  emit('save', text.value.trim(), category.value);
  dialogRef.value?.close();
}

onMounted(() => {
  dialogRef.value?.showModal();
  // A new note starts typing; changing one leaves the category in view.
  if (!text.value) textareaRef.value?.focus();
});
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    class="m-auto w-full max-w-lg overflow-y-auto rounded-2xl bg-surface p-0 backdrop:bg-ink/40 max-sm:mb-0 max-sm:max-w-none max-sm:rounded-b-none"
    @close="emit('close')"
  >
    <form class="pb-8" @submit.prevent="save">
      <div class="sticky top-0 flex items-center gap-2 bg-surface px-4 py-3">
        <div class="flex flex-1 basis-0">
          <button
            type="button"
            class="min-h-11 rounded-lg px-1 text-base text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand"
            @click="cancel"
          >
            {{ AYLA_CANCEL }}
          </button>
        </div>
        <h2 :id="titleId" class="truncate text-base font-semibold text-heading">{{ title }}</h2>
        <div class="flex flex-1 basis-0 justify-end">
          <button
            type="submit"
            :disabled="!canSave"
            class="min-h-11 rounded-lg px-1 text-base font-semibold text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand disabled:text-ink-soft disabled:no-underline"
          >
            {{ AYLA_SAVE }}
          </button>
        </div>
      </div>

      <div class="px-4 pt-2">
        <label :for="textId" class="sr-only">{{ MEMORY_ADD }}</label>
        <textarea
          :id="textId"
          ref="textarea"
          v-model="text"
          rows="3"
          :maxlength="MAX_MEMORY_LENGTH"
          :placeholder="MEMORY_ADD_PLACEHOLDER"
          :aria-describedby="footerId"
          class="block w-full resize-none rounded-xl bg-white px-4 py-3 text-sm font-medium text-heading placeholder:text-ink-soft focus-visible:outline-2 focus-visible:outline-brand"
        />
        <p :id="footerId" class="mt-2 px-4 text-xs/normal text-subtle">{{ MEMORY_EDITOR_FOOTER }}</p>

        <fieldset class="mt-6">
          <legend class="mb-2 px-4 text-sm font-medium text-subtle">{{ MEMORY_CATEGORY_LABEL }}</legend>
          <div class="divide-y divide-line overflow-hidden rounded-xl bg-white">
            <label
              v-for="option in MEMORY_CATEGORIES"
              :key="option.id"
              class="flex min-h-11 cursor-pointer items-center gap-3 px-4 py-2.5 hover:bg-surface has-focus-visible:outline-2 has-focus-visible:-outline-offset-2 has-focus-visible:outline-brand"
            >
              <input v-model="category" type="radio" name="memory-category" :value="option.id" class="sr-only" />
              <span class="flex-1 text-sm text-heading">{{ option.title }}</span>
              <LayoutPaveIcon v-if="category === option.id" name="check" class="size-4.5 text-brand" />
            </label>
          </div>
        </fieldset>
      </div>
    </form>
  </dialog>
</template>
