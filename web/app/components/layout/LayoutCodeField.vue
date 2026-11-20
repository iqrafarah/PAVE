<script setup lang="ts">
// A code in separate boxes, one digit each: the code of two-step verification and the PIN of locked chats.
// One real field lies invisibly over the boxes, so typing, pasting, the phone's number pad and filling in the code
// from a text message all work as in any field, and a screen reader hears one field with its label.
const props = withDefaults(
  defineProps<{
    id: string;
    length: number;
    // The PIN: dots instead of digits.
    isMasked?: boolean;
    isInvalid?: boolean;
    isDisabled?: boolean;
    // The boxes share the full width instead of stopping at a maximum size.
    isFluid?: boolean;
    describedBy?: string;
    autocomplete?: string;
  }>(),
  { autocomplete: 'off' },
);

const emit = defineEmits<{
  complete: [code: string];
}>();

const code = defineModel<string>({ required: true });
const inputRef = useTemplateRef<HTMLInputElement>('input');
const isFocused = ref(false);

// The box the next digit goes in; with every box full, the last one.
const activeIndex = computed(() => Math.min(code.value.length, props.length - 1));

function handleInput(event: Event) {
  const input = event.target as HTMLInputElement;
  const digits = input.value.replace(/\D/g, '').slice(0, props.length);
  input.value = digits;
  const isNewlyComplete = digits.length === props.length && digits !== code.value;
  code.value = digits;
  if (isNewlyComplete) emit('complete', digits);
}

function boxClass(index: number) {
  if (props.isInvalid) return 'border-danger';
  if (isFocused.value && index === activeIndex.value) return 'border-brand outline-2 outline-brand/25';
  return 'border-line';
}

function focus() {
  inputRef.value?.focus({ preventScroll: true });
}

defineExpose({ focus });
</script>

<template>
  <div class="relative flex gap-2.5" :class="{ 'opacity-60': isDisabled }">
    <span
      v-for="index in length"
      :key="index"
      :class="[boxClass(index - 1), isFluid ? '' : 'max-w-14']"
      class="flex h-14 min-w-0 flex-1 items-center justify-center rounded-lg border bg-white text-xl font-semibold text-heading transition-colors"
      aria-hidden="true"
    >
      <template v-if="index <= code.length">{{ isMasked ? '•' : code[index - 1] }}</template>
      <span
        v-else-if="isFocused && index - 1 === activeIndex"
        class="h-6 w-px animate-pulse bg-heading motion-reduce:animate-none"
      />
    </span>
    <input
      :id="id"
      ref="input"
      :value="code"
      :type="isMasked ? 'password' : 'text'"
      inputmode="numeric"
      :autocomplete="autocomplete"
      :pattern="`[0-9]{${length}}`"
      :disabled="isDisabled"
      :aria-invalid="isInvalid"
      :aria-describedby="describedBy"
      required
      class="absolute inset-0 size-full cursor-text text-transparent caret-transparent opacity-0 outline-none selection:bg-transparent"
      @input="handleInput"
      @focus="isFocused = true"
      @blur="isFocused = false"
    />
  </div>
</template>
