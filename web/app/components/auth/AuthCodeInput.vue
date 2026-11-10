<script setup lang="ts">
const CODE_LENGTH = 6;
const NON_DIGITS = /\D/g;

const props = defineProps<{
  id: string;
  label: string;
  hint?: string;
  error?: string;
  isAutofocused?: boolean;
}>();

const code = defineModel<string>({ required: true });

const inputRef = useTemplateRef<HTMLInputElement>('input');

const hintId = computed(() => `${props.id}-hint`);
const errorId = computed(() => `${props.id}-error`);
const hasError = computed(() => Boolean(props.error));
const describedBy = computed(() => (hasError.value ? errorId.value : hintId.value));
const borderClass = computed(() => (hasError.value ? 'border-danger' : 'border-line'));

function setDigits(input: HTMLInputElement, text: string) {
  const digits = text.replace(NON_DIGITS, '').slice(0, CODE_LENGTH);
  input.value = digits;
  code.value = digits;
}

function handleInput(event: Event) {
  const input = event.target as HTMLInputElement;
  setDigits(input, input.value);
}

function handlePaste(event: ClipboardEvent) {
  const pastedText = event.clipboardData?.getData('text') ?? '';
  setDigits(event.target as HTMLInputElement, pastedText);
}

function focusInput() {
  if (props.isAutofocused) inputRef.value?.focus();
}

// A wrong code empties the field, so put the cursor back for the next try.
watch(hasError, (isNowError) => {
  if (isNowError) focusInput();
});
onMounted(focusInput);
</script>

<template>
  <div>
    <label :for="id" class="block text-sm font-medium text-ink">
      {{ label }}
    </label>
    <input
      :id="id"
      ref="input"
      :value="code"
      type="text"
      required
      inputmode="numeric"
      autocomplete="one-time-code"
      :maxlength="CODE_LENGTH"
      :pattern="`[0-9]{${CODE_LENGTH}}`"
      placeholder="000000"
      :aria-invalid="hasError"
      :aria-describedby="describedBy"
      :class="borderClass"
      class="mt-2 h-13 w-full rounded-lg border px-3.5 text-lg tracking-code text-ink placeholder:text-muted focus-visible:outline-2 focus-visible:outline-brand"
      @input="handleInput"
      @paste.prevent="handlePaste"
    />
    <p v-if="hasError" :id="errorId" role="alert" class="mt-2 text-sm text-danger">
      {{ error }}
    </p>
    <p v-else-if="hint" :id="hintId" class="mt-2 text-sm text-muted">
      {{ hint }}
    </p>
  </div>
</template>
