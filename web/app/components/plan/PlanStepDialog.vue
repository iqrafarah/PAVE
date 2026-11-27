<script setup lang="ts">
import type { PlanStep, PlanStepKind } from '~/types/plan';

// "Stap toevoegen" and "Stap aanpassen" (iOS PlanStepEditor): what you are going to do, a short explanation, and what
// kind of step it is. Changing a step can also delete it.
const props = defineProps<{
  // Null: a new step.
  step: PlanStep | null;
}>();

const isOpen = defineModel<boolean>('open', { required: true });

const emit = defineEmits<{
  save: [step: { title: string; summary: string; kind: PlanStepKind }];
  delete: [];
}>();

const title = ref('');
const summary = ref('');
const kind = ref<PlanStepKind>('general');
const titleError = ref(false);
const ids = { title: useId(), summary: useId(), kind: useId() };

watch(isOpen, (open) => {
  if (!open) return;
  title.value = props.step?.title ?? '';
  summary.value = props.step?.summary ?? '';
  kind.value = props.step?.kind ?? 'general';
  titleError.value = false;
});

function save() {
  const clean = cleanPlanName(title.value);
  if (!clean) {
    titleError.value = true;
    return;
  }
  emit('save', { title: clean, summary: cleanPlanGoal(summary.value), kind: kind.value });
  isOpen.value = false;
}

const field = 'w-full rounded-field border border-field-line bg-white px-3 text-sm font-medium text-heading outline-none focus:border-brand aria-invalid:border-danger';
const label = 'text-sm font-semibold text-heading';
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="step ? PLAN_EDIT_STEP : PLAN_ADD_STEP" width="narrow">
    <form id="plan-step" class="flex flex-col gap-5 pb-2" novalidate @submit.prevent="save">
      <div class="flex flex-col gap-1.5">
        <label :for="ids.title" :class="label">{{ PLAN_STEP_TITLE_LABEL }}</label>
        <input
          :id="ids.title"
          v-model="title"
          type="text"
          :maxlength="PLAN_NAME_MAX"
          :placeholder="PLAN_STEP_TITLE_PLACEHOLDER"
          :aria-invalid="titleError"
          :class="field"
          class="h-11"
          @input="titleError = false"
        />
      </div>
      <div class="flex flex-col gap-1.5">
        <label :for="ids.summary" :class="label">{{ PLAN_STEP_SUMMARY_LABEL }}</label>
        <textarea
          :id="ids.summary"
          v-model="summary"
          rows="3"
          :maxlength="PLAN_GOAL_MAX"
          :placeholder="PLAN_STEP_SUMMARY_PLACEHOLDER"
          :class="field"
          class="resize-y py-2.5"
        />
      </div>
      <fieldset class="flex flex-col gap-2">
        <legend :id="ids.kind" class="mb-2 text-sm font-semibold text-heading">{{ PLAN_KIND_LABEL }}</legend>
        <div class="grid grid-cols-[repeat(auto-fill,minmax(9.5rem,1fr))] gap-2">
          <label
            v-for="option in PLAN_CHOOSABLE_KINDS"
            :key="option"
            :class="kind === option ? 'border-brand bg-tint' : 'border-card-border bg-white hover:bg-surface'"
            class="flex cursor-pointer items-center gap-2 rounded-xl border px-3 py-2 text-sm font-medium text-heading has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand"
          >
            <input v-model="kind" type="radio" name="plan-step-kind" :value="option" class="sr-only" />
            <VaultIcon :src="planStepIcon(option)" class="size-4 shrink-0 text-brand" />
            {{ planKindTitle(option) }}
          </label>
        </div>
      </fieldset>
      <button
        v-if="step"
        type="button"
        class="flex min-h-10 items-center gap-2 self-start rounded-field px-2 text-sm font-semibold text-danger hover:bg-status-rejected-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('delete'); isOpen = false"
      >
        <LayoutPaveIcon name="trash" class="size-4" />
        {{ PLAN_DELETE_STEP }}
      </button>
    </form>

    <template #footer>
      <button
        type="submit"
        form="plan-step"
        class="min-h-11 w-full rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      >
        {{ step ? PLAN_SAVE : PLAN_ADD_STEP }}
      </button>
    </template>
  </VaultSheet>
</template>
