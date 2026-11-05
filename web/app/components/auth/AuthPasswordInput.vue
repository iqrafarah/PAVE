<script setup lang="ts">
const props = defineProps<{
  id: string;
  label: string;
  placeholder: string;
  autocomplete: 'current-password' | 'new-password';
  error?: string;
}>();

const password = defineModel<string>({ required: true });

const isVisible = ref(false);

const errorId = computed(() => `${props.id}-error`);
const hasError = computed(() => Boolean(props.error));
const inputType = computed(() => (isVisible.value ? 'text' : 'password'));
const toggleText = computed(() => (isVisible.value ? 'Hide' : 'Show'));
const borderClass = computed(() => (hasError.value ? 'border-danger' : 'border-line'));
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
        :aria-describedby="hasError ? errorId : undefined"
        :class="borderClass"
        class="h-13 w-full rounded-lg border pl-3.5 pr-24 text-base text-ink placeholder:text-muted focus-visible:outline-2 focus-visible:outline-brand"
      />
      <button
        type="button"
        :aria-controls="id"
        :aria-label="`${toggleText} password`"
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
  </div>
</template>
