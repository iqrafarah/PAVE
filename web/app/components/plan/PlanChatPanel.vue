<script setup lang="ts">
import type { Plan, PlanStep } from '~/types/plan';

// The steps of the open chat's plan, in the chat panel where the chats are (Figma FEDDIES 1363:2656; on iOS the Dynamic
// Bar): a timeline with a mark per step, the moment it was done, its title and a line about it. A tap on a mark finishes
// that step or puts it back, as on the Plan page.
const props = defineProps<{
  plan: Plan;
}>();

const plans = usePlans();
const finished = ref<PlanStep | null>(null);
const titleId = useId();
const FINISHED_ANNOUNCED_MS = 1800;
let finishedTimer: ReturnType<typeof setTimeout> | undefined;

const done = computed(() => doneCount(props.plan));

/** "15 jan 2024, 09:00", as in the design; only for a step that is done. */
function doneAt(step: PlanStep) {
  if (step.status !== 'done' || !step.completedAt) return null;
  const at = new Date(step.completedAt);
  if (Number.isNaN(at.getTime())) return null;
  const day = at.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short', year: 'numeric' }).replace('.', '');
  const time = at.toLocaleTimeString('nl-NL', { hour: '2-digit', minute: '2-digit' });
  return `${day}, ${time}`;
}

function toggle(step: PlanStep) {
  plans.setStatus(props.plan.id, step.id, step.status === 'done' ? 'upcoming' : 'done');
}

/** The step that was done last, said by the screen reader. */
function lastFinished() {
  return props.plan.steps
    .filter((step) => step.status === 'done')
    .reduce<PlanStep | null>((latest, step) => (!latest || (step.completedAt ?? '') > (latest.completedAt ?? '') ? step : latest), null);
}

watch(done, (now, before) => {
  if (now <= before) return;
  finished.value = lastFinished();
  clearTimeout(finishedTimer);
  finishedTimer = setTimeout(() => (finished.value = null), FINISHED_ANNOUNCED_MS);
});

onBeforeUnmount(() => clearTimeout(finishedTimer));
</script>

<template>
  <section :aria-labelledby="titleId" class="flex min-h-0 flex-1 flex-col">
    <h2 :id="titleId" class="sr-only">{{ PLAN_TITLE }}: <span translate="no">{{ plan.name }}</span></h2>
    <p aria-live="polite" class="sr-only">
      <template v-if="finished">{{ PLAN_STEP_FINISHED }}: {{ finished.title }}</template>
    </p>

    <p v-if="!plan.steps.length" class="font-step text-xs text-subtle">{{ PLAN_NO_STEPS }}</p>
    <ol v-else class="quiet-scroll flex min-h-0 flex-1 flex-col overflow-y-auto" :aria-label="PLAN_STEPS">
      <li v-for="(step, index) in plan.steps" :key="step.id" class="relative flex gap-3.5 pb-5.5 last:pb-1">
        <!-- The line to the next step: green after a step that is done. -->
        <span
          v-if="index < plan.steps.length - 1"
          :class="step.status === 'done' ? 'bg-brand' : 'bg-rail-line'"
          class="absolute bottom-1 left-2.5 top-6.5 w-px"
          aria-hidden="true"
        />
        <button
          type="button"
          :aria-label="`${step.title}: ${PLAN_STATUS[step.status]}`"
          :aria-pressed="step.status === 'done'"
          :title="step.status === 'done' ? PLAN_MARK_UPCOMING : PLAN_MARK_DONE"
          class="relative mt-0.5 shrink-0 self-start rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="toggle(step)"
        >
          <PlanStepMark :status="step.status" />
        </button>
        <span class="flex min-w-0 flex-col font-step">
          <span v-if="doneAt(step)" class="text-step-date font-semibold text-subtle">{{ doneAt(step) }}</span>
          <span
            translate="no"
            :class="step.status === 'skipped' ? 'text-subtle line-through' : 'text-heading'"
            class="text-sm font-semibold"
          >
            {{ step.title }}
          </span>
          <span v-if="step.summary" translate="no" class="text-xs text-subtle">{{ step.summary }}</span>
          <span v-else class="text-xs text-subtle">{{ planKindTitle(step.kind) }}</span>
        </span>
      </li>
    </ol>
  </section>
</template>
