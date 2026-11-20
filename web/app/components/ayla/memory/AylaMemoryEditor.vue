<script setup lang="ts">
import type { MemoryCategory } from '~/types/ayla';

// Writing a note yourself, or changing one (iOS AylaMemoryEditor, a sheet): "Annuleren", the title and "Bewaren" on
// top, the text with its footer, and the folders as tiles to tick: a note can be in more than one, as on iOS. Opens as soon as it is shown.
const props = defineProps<{
  title: string;
  initialText: string;
  initialCategories: MemoryCategory[];
}>();

const emit = defineEmits<{
  save: [text: string, categories: MemoryCategory[]];
  close: [];
}>();

const text = ref(props.initialText);
const categories = ref<MemoryCategory[]>(props.initialCategories.length ? [...props.initialCategories] : ['personal']);
const dialogRef = useTemplateRef<HTMLDialogElement>('dialog');
const textareaRef = useTemplateRef<HTMLTextAreaElement>('textarea');
const titleId = useId();
const textId = useId();
const footerId = useId();
const categoryHintId = useId();

const canSave = computed(() => text.value.trim().length > 0);

function cancel() {
  dialogRef.value?.close();
}

/** Ticking adds the folder at the end; the last one cannot be unticked, a note always belongs somewhere. */
function toggle(id: MemoryCategory) {
  if (!categories.value.includes(id)) categories.value = [...categories.value, id];
  else if (categories.value.length > 1) categories.value = categories.value.filter((value) => value !== id);
}

function save() {
  if (!canSave.value) return;
  emit('save', text.value.trim(), categories.value);
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
            class="min-h-11 rounded-lg px-3 text-base text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
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
            class="min-h-11 rounded-lg px-3 text-base font-semibold text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand disabled:text-ink-soft disabled:hover:bg-transparent"
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
          <legend class="mb-1 px-4 text-sm font-medium text-subtle">{{ MEMORY_CATEGORY_LABEL }}</legend>
          <p :id="categoryHintId" class="mb-3 px-4 text-xs/normal text-subtle">{{ MEMORY_CATEGORY_FOOTER }}</p>
          <ul class="grid grid-cols-2 gap-2">
            <li v-for="option in MEMORY_CATEGORIES" :key="option.id">
              <label
                :class="
                  categories.includes(option.id) ? 'border-brand bg-brand-soft' : 'border-card-border bg-white hover:bg-tint'
                "
                class="flex min-h-14 cursor-pointer items-center gap-2.5 rounded-xl border px-3 py-2 has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand"
              >
                <input
                  type="checkbox"
                  :checked="categories.includes(option.id)"
                  :aria-describedby="categoryHintId"
                  class="sr-only"
                  @change="toggle(option.id)"
                />
                <span
                  :class="MEMORY_CATEGORY_STYLES[option.id].tintClass"
                  class="flex size-8 shrink-0 items-center justify-center rounded-lg text-brand"
                  aria-hidden="true"
                >
                  <LayoutPaveIcon :name="MEMORY_CATEGORY_STYLES[option.id].icon" class="size-4" />
                </span>
                <span class="min-w-0 flex-1 text-sm font-medium leading-tight text-heading">{{ option.title }}</span>
                <LayoutPaveIcon
                  v-if="categories.includes(option.id)"
                  name="check"
                  class="size-4 shrink-0 text-brand"
                  aria-hidden="true"
                />
              </label>
            </li>
          </ul>
        </fieldset>
      </div>
    </form>
  </dialog>
</template>
