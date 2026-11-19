<script setup lang="ts">
// "Chats automatisch verwijderen" in Privacy, like the disappearing messages of WhatsApp: a dropdown with never, or
// after 24 hours, 30 or 90 days. A shorter time asks first, because what is old enough goes at the next hour and
// cannot come back.
const retention = useAylaChatRetention();
const selectId = useId();
const hintId = useId();
const problem = ref<string | null>(null);
const pending = ref<(typeof SETTINGS_AUTO_DELETE_OPTIONS)[number] | null>(null);
const confirmRef = useTemplateRef<{ open: () => void }>('confirm');

const status = computed(() => retention.state.value.status);
const chosen = computed({
  get: () => String(retention.state.value.days ?? 'never'),
  set: (value: string) => {
    const option = SETTINGS_AUTO_DELETE_OPTIONS.find((item) => item.value === value);
    if (!option || option.days === retention.state.value.days) return;
    problem.value = null;
    // Turning it off, or making it longer, loses nothing: no question.
    if (option.days === null || (retention.state.value.days !== null && option.days > retention.state.value.days)) {
      apply(option.days);
      return;
    }
    pending.value = option;
    confirmRef.value?.open();
  },
});

async function apply(days: number | null) {
  const { isFailed } = await retention.setDays(days);
  if (isFailed) problem.value = SETTINGS_AUTO_DELETE_FAILED;
}

function confirm() {
  const option = pending.value;
  pending.value = null;
  if (option) apply(option.days);
}

// Cancelling leaves the old choice in the dropdown.
function resetSelect(event: Event) {
  (event.target as HTMLSelectElement).value = chosen.value;
}

function handleChange(event: Event) {
  const select = event.target as HTMLSelectElement;
  chosen.value = select.value;
  // A choice that waits for the question shows the saved one until it is confirmed.
  if (pending.value) resetSelect(event);
}

onMounted(() => {
  if (status.value === 'idle') retention.load();
});
</script>

<template>
  <SettingsGroup v-if="status === 'ready'">
    <div class="flex items-center gap-4 p-4">
      <div class="min-w-0 flex-1">
        <label :for="selectId" class="block text-base font-semibold text-heading">{{ SETTINGS_AUTO_DELETE_TITLE }}</label>
        <p :id="hintId" class="text-sm text-subtle">{{ SETTINGS_AUTO_DELETE_HINT }}</p>
        <p v-if="problem" role="alert" class="mt-1 text-sm text-danger">{{ problem }}</p>
      </div>
      <span class="relative shrink-0">
        <select
          :id="selectId"
          :value="chosen"
          :aria-describedby="hintId"
          class="min-h-10 cursor-pointer appearance-none rounded-pill bg-tint py-2 pl-5 pr-11 text-base font-medium text-heading hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @change="handleChange"
        >
          <option v-for="option in SETTINGS_AUTO_DELETE_OPTIONS" :key="option.value" :value="option.value">
            {{ option.label }}
          </option>
        </select>
        <LayoutPaveIcon
          name="chevronDown"
          class="pointer-events-none absolute right-4 top-1/2 size-3 -translate-y-1/2 text-heading"
          aria-hidden="true"
        />
      </span>
    </div>

    <LayoutConfirmSheet
      ref="confirm"
      :title="SETTINGS_AUTO_DELETE_TITLE"
      :message="pending ? getAutoDeleteQuestion(pending.period) : undefined"
      :confirm-label="pending?.label ?? ''"
      @confirm="confirm"
    />
  </SettingsGroup>
</template>
