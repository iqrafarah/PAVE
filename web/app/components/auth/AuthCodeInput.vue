<script setup lang="ts">
const CODE_LENGTH = 6;
const NON_DIGITS = /\D/g;

const props = defineProps<{
  id: string;
  hint?: string;
  error?: string;
}>();

const code = defineModel<string>({ required: true });

const hintId = computed(() => `${props.id}-hint`);
const errorId = computed(() => `${props.id}-error`);
const hasError = computed(() => Boolean(props.error));
const describedBy = computed(() => (hasError.value ? errorId.value : hintId.value));
const borderClass = computed(() => (hasError.value ? 'border-danger' : 'border-line'));

function handleInput(event: Event) {
  const input = event.target as HTMLInputElement;
  const digits = input.value.replace(NON_DIGITS, '').slice(0, CODE_LENGTH);
  input.value = digits;
  code.value = digits;
}
</script>

<template>
  <div class="mt-8">
    <label :for="id" class="block text-sm font-medium text-ink">
      {{ CODE_LENGTH }}-digit code
    </label>
    <input
      :id="id"
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
    />
    <p v-if="hasError" :id="errorId" role="alert" class="mt-2 text-sm text-danger">
      {{ error }}
    </p>
    <p v-else-if="hint" :id="hintId" class="mt-2 text-sm text-muted">
      {{ hint }}
    </p>
  </div>
</template>
