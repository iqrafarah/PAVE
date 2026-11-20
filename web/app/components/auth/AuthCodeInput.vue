<script setup lang="ts">
const CODE_LENGTH = 6;

const props = defineProps<{
  id: string;
  label: string;
  hint?: string;
  error?: string;
  isAutofocused?: boolean;
}>();

const code = defineModel<string>({ required: true });

const rootRef = useTemplateRef<HTMLDivElement>('root');
const fieldRef = useTemplateRef<{ focus: () => void }>('field');

const hintId = computed(() => `${props.id}-hint`);
const errorId = computed(() => `${props.id}-error`);
const hasError = computed(() => Boolean(props.error));
const describedBy = computed(() => (hasError.value ? errorId.value : hintId.value));

// With the last digit typed or pasted the form sends itself, as people are used to: no extra click or Enter.
async function submit() {
  // Wait until the page has the code, then submit like the button would (with the form's own checks).
  await nextTick();
  const form = rootRef.value?.closest('form');
  // Not while the form cannot be sent yet (its button is disabled, for example while a check is still running).
  const button = form?.querySelector<HTMLButtonElement>('button[type="submit"]');
  if (button && !button.disabled) form?.requestSubmit(button);
}

function focusInput() {
  if (props.isAutofocused) fieldRef.value?.focus();
}

// A wrong code empties the field, so put the cursor back for the next try.
watch(hasError, (isNowError) => {
  if (isNowError) focusInput();
});
onMounted(focusInput);
</script>

<template>
  <div ref="root">
    <label :for="id" class="block text-sm font-medium text-ink">
      {{ label }}
    </label>
    <LayoutCodeField
      :id="id"
      ref="field"
      v-model="code"
      class="mt-2"
      is-fluid
      :length="CODE_LENGTH"
      autocomplete="one-time-code"
      :is-invalid="hasError"
      :described-by="describedBy"
      @complete="submit"
    />
    <p v-if="hasError" :id="errorId" role="alert" class="mt-2 text-sm text-danger">
      {{ error }}
    </p>
    <p v-else-if="hint" :id="hintId" class="mt-2 text-sm text-muted">
      {{ hint }}
    </p>
  </div>
</template>
