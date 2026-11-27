<script setup lang="ts">
import type { AylaPlanEdit, AylaPlanEditChange } from '~/types/ayla';

// Under Ayla's answer when she proposes changes to the plan so it reaches its goal (iOS AylaPlanEditCard): new steps,
// steps that can go, steps in another order, each with why. Untick what you do not want; nothing changes before
// "Pas plan aan".
const props = defineProps<{
  edit: AylaPlanEdit;
}>();

const plans = usePlans();
const unticked = ref<Set<number>>(new Set());
const titleId = useId();

const plan = computed(() => plans.find(props.edit.planId));
const decision = computed(() => plans.editDecisions.value[props.edit.id] ?? null);
const chosen = computed(() => props.edit.changes.filter((_, index) => !unticked.value.has(index)));

function toggle(index: number) {
  const next = new Set(unticked.value);
  if (next.has(index)) next.delete(index);
  else next.add(index);
  unticked.value = next;
}

/** Where a new or moved step lands, by the step before it. */
function placeOf(change: AylaPlanEditChange) {
  if (change.op === 'remove') return null;
  if (!change.afterStepId) return PLAN_EDIT_AT_START;
  const after = plan.value?.steps.find((step) => step.id === change.afterStepId);
  return after ? PLAN_EDIT_AFTER(after.title) : null;
}

function headingOf(change: AylaPlanEditChange) {
  return [PLAN_EDIT_OPS[change.op], placeOf(change)].filter(Boolean).join(' · ');
}

onMounted(() => {
  plans.loadEditDecisions();
  if (plans.state.value.status === 'idle') plans.load(true);
});
</script>

<template>
  <NuxtLink
    v-if="plan && decision === 'applied'"
    :to="{ path: '/plan', query: { plan: plan.id } }"
    class="flex w-fit items-center gap-1.5 rounded-lg px-1 text-sm font-medium text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand"
  >
    <LayoutPaveIcon name="check" class="size-3.5" />
    {{ PLAN_EDIT_DONE }} · <span class="underline">{{ PLAN_OPEN }}</span>
  </NuxtLink>

  <section
    v-else-if="plan && !decision"
    :aria-labelledby="titleId"
    class="flex flex-col gap-3.5 rounded-2xl border border-card-line bg-white p-4"
  >
    <header class="flex items-center gap-2.5">
      <AylaSlashIcon :blocks="4" class="h-4 w-2.5 shrink-0" />
      <span class="flex min-w-0 flex-col">
        <h2 :id="titleId" class="text-sm font-semibold text-heading">{{ PLAN_EDIT_TITLE }}</h2>
        <span translate="no" class="truncate text-xs text-subtle">{{ plan.name }}</span>
      </span>
    </header>

    <ul class="flex flex-col gap-3 rounded-xl bg-tint p-3">
      <li v-for="(change, index) in edit.changes" :key="index">
        <label class="flex cursor-pointer items-start gap-2.5">
          <input
            type="checkbox"
            :checked="!unticked.has(index)"
            class="mt-0.5 size-4 shrink-0 accent-brand"
            @change="toggle(index)"
          />
          <span class="flex min-w-0 flex-col gap-0.5">
            <span :class="change.op === 'remove' ? 'text-danger' : 'text-brand'" class="text-xs font-semibold">{{ headingOf(change) }}</span>
            <span
              translate="no"
              :class="change.op === 'remove' && !unticked.has(index) ? 'text-subtle line-through' : 'text-heading'"
              class="text-sm font-medium"
            >
              {{ change.title }}
            </span>
            <span v-if="change.why" class="text-xs text-subtle">{{ change.why }}</span>
          </span>
        </label>
      </li>
    </ul>

    <div class="flex gap-2">
      <button
        type="button"
        class="flex min-h-11 flex-1 items-center justify-center rounded-pill bg-tint px-4 text-sm font-medium text-heading hover:bg-brand/15 focus-visible:outline-2 focus-visible:outline-brand"
        @click="plans.decideEdit(edit.id, 'declined')"
      >
        {{ PLAN_EDIT_NOT_YET }}
      </button>
      <button
        type="button"
        :disabled="!chosen.length"
        class="flex min-h-11 flex-1 items-center justify-center rounded-pill bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:bg-tint disabled:text-subtle"
        @click="plans.applyEdit(edit, chosen)"
      >
        {{ PLAN_EDIT_APPLY }}
      </button>
    </div>
  </section>
</template>
