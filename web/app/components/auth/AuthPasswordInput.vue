<script setup lang="ts">
import type { PasswordFieldState } from '~/utils/auth/passwordRules';

type FieldLook = 'error' | 'neutral' | PasswordFieldState;

const FIELD_LOOK_CLASS: Record<FieldLook, string> = {
  error: 'border-danger focus-visible:outline-danger',
  neutral: 'border-line focus-visible:outline-brand',
  incomplete: 'border-warning focus-visible:outline-warning',
  valid: 'border-brand focus-visible:outline-brand',
};

const props = defineProps<{
  id: string;
  label: string;
  placeholder: string;
  autocomplete: 'current-password' | 'new-password';
  error?: string;
  state?: PasswordFieldState;
  status?: string;
  hint?: string;
  isCopyBlocked?: boolean;
  isPasteBlocked?: boolean;
}>();

const emit = defineEmits<{
  blur: [];
}>();

const password = defineModel<string>({ required: true });

const isVisible = ref(false);
const isCapsLockOn = ref(false);

const errorId = computed(() => `${props.id}-error`);
const statusId = computed(() => `${props.id}-status`);
const hintId = computed(() => `${props.id}-hint`);
const hasError = computed(() => Boolean(props.error));
const isEmpty = computed(() => password.value.length === 0);
const isValid = computed(() => props.state === 'valid');
const isStatusVisible = computed(() => Boolean(props.status) && !hasError.value && !isEmpty.value);
const inputType = computed(() => (isVisible.value ? 'text' : 'password'));
const toggleText = computed(() => (isVisible.value ? 'Verbergen' : 'Tonen'));

const describedBy = computed(() => {
  const ids: string[] = [];
  if (hasError.value) ids.push(errorId.value);
  if (isStatusVisible.value) ids.push(statusId.value);
  if (props.hint) ids.push(hintId.value);
  return ids.length > 0 ? ids.join(' ') : undefined;
});

const fieldLook = computed<FieldLook>(() => {
  if (hasError.value) return 'error';
  if (!props.state || isEmpty.value) return 'neutral';
  return props.state;
});

function updateCapsLock(event: KeyboardEvent) {
  // Browser autofill can fire key events without getModifierState.
  if (typeof event.getModifierState !== 'function') return;
  isCapsLockOn.value = event.getModifierState('CapsLock');
}

function handleBlur() {
  isCapsLockOn.value = false;
  emit('blur');
}

function blockCopy(event: Event) {
  if (props.isCopyBlocked) event.preventDefault();
}

function blockPaste(event: Event) {
  if (props.isPasteBlocked) event.preventDefault();
}
</script>

<template>
  <div>
    <label :for="id" class="block text-sm font-medium text-ink">{{ label }}</label>
    <div class="relative mt-2">
      <input
        :id="id"
        v-model="password"
        :type="inputType"
        required
        :autocomplete="autocomplete"
        :placeholder="placeholder"
        :aria-invalid="hasError"
        :aria-describedby="describedBy"
        :class="FIELD_LOOK_CLASS[fieldLook]"
        class="h-13 w-full rounded-lg border pl-3.5 pr-24 text-base text-ink placeholder:text-muted focus-visible:outline-2"
        @keydown="updateCapsLock"
        @keyup="updateCapsLock"
        @blur="handleBlur"
        @copy="blockCopy"
        @cut="blockCopy"
        @paste="blockPaste"
        @drop="blockPaste"
      />
      <button
        type="button"
        :aria-controls="id"
        :aria-label="`Wachtwoord ${toggleText.toLowerCase()}`"
        class="absolute right-3.5 top-1/2 flex -translate-y-1/2 items-center gap-2 text-sm font-medium text-ink focus-visible:outline-2 focus-visible:outline-brand"
        @click="isVisible = !isVisible"
      >
        <svg
          class="size-5"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z"
          />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"
          />
        </svg>
        {{ toggleText }}
      </button>
    </div>
    <p
      v-if="hasError"
      :id="errorId"
      role="alert"
      class="mt-2 flex items-center gap-1.5 text-sm text-danger"
    >
      <svg
        class="size-4 shrink-0"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z"
        />
      </svg>
      {{ error }}
    </p>
    <div v-if="status" aria-live="polite">
      <p
        v-if="isStatusVisible"
        :id="statusId"
        class="mt-2 flex items-center gap-1.5 text-sm text-ink"
      >
        <AuthCheckIcon :is-checked="isValid" />
        {{ status }}
      </p>
    </div>
    <p v-if="hint" :id="hintId" class="mt-2 text-sm text-muted">{{ hint }}</p>
    <div aria-live="polite">
      <p
        v-if="isCapsLockOn"
        class="mt-2 inline-flex items-center gap-1.5 rounded-md bg-warning-soft px-2 py-1 text-sm font-medium text-warning"
      >
        <svg
          class="size-4 shrink-0"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M4.5 10.5 12 3m0 0 7.5 7.5M12 3v18"
          />
        </svg>
        {{ CAPS_LOCK_ON_MESSAGE }}
      </p>
    </div>
  </div>
</template>
