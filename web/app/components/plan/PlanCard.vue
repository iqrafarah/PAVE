<script setup lang="ts">
import type { Plan } from '~/types/plan';

// One plan in the list (iOS PlanScreen row): its icon and name, the step you are on and how far it is.
const props = defineProps<{
  plan: Plan;
}>();

const emit = defineEmits<{
  open: [];
}>();

const total = computed(() => totalCount(props.plan));
const progressLabel = computed(() => PLAN_PROGRESS_DONE(doneCount(props.plan), total.value));
const line = computed(() => {
  if (isPlanFinished(props.plan)) return progressLabel.value;
  const step = currentStep(props.plan);
  if (!step) return props.plan.goal || PLAN_NO_STEPS;
  return `${PLAN_STEP_NUMBER(currentNumber(props.plan), total.value)} · ${step.title}`;
});
</script>

<template>
  <button
    type="button"
    class="flex w-full items-center gap-3.5 rounded-2xl border border-card-line bg-white p-4 text-left hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
    @click="emit('open')"
  >
    <PlanBadge :template-id="plan.templateId" />
    <span class="flex min-w-0 flex-1 flex-col gap-1.5">
      <span translate="no" class="truncate text-base font-semibold text-heading">{{ plan.name }}</span>
      <span class="truncate text-xs text-subtle">{{ line }}</span>
      <PlanProgressBar v-if="total" :progress="planProgress(plan)" :label="progressLabel" />
    </span>
    <LayoutPaveIcon name="chevronRight" class="size-3.5 shrink-0 text-brand" />
  </button>
</template>
