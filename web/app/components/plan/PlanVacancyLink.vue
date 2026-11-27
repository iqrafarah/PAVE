<script setup lang="ts">
import type { Vacancy } from '~/types/ayla';

// On a vacancy (iOS VacancyPlanLink): make a plan towards applying for it, or open the plan you already have for it,
// with how far you are. The plan gets steps for what you still miss, your CV and letter, sharing and the talk.
const props = defineProps<{
  vacancy: Vacancy;
}>();

const plans = usePlans();
const isMaking = ref(false);
const plan = computed(() => plans.planForVacancy(props.vacancy.id));
const line = computed(() =>
  plan.value
    ? `${PLAN_PROGRESS(doneCount(plan.value), totalCount(plan.value))} stappen afgerond`
    : planVacancyHint(props.vacancy.skillGap.length),
);

async function go() {
  if (isMaking.value) return;
  isMaking.value = true;
  const made = plan.value ?? (await plans.planVacancy(props.vacancy));
  isMaking.value = false;
  if (made) await navigateTo({ path: '/plan', query: { plan: made.id } });
}

onMounted(() => {
  if (plans.state.value.status === 'idle') plans.load(true);
});
</script>

<template>
  <button
    v-if="plans.state.value.status === 'ready'"
    type="button"
    :disabled="isMaking"
    class="mt-3 flex w-full items-center gap-3 rounded-xl border border-card-border bg-white p-3 text-left hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60"
    @click="go"
  >
    <VaultIcon src="/images/plan/general.svg" class="size-4.5 shrink-0 text-brand" />
    <span class="flex min-w-0 flex-1 flex-col gap-0.5">
      <span class="text-sm font-semibold text-heading">{{ plan ? PLAN_VACANCY_OPEN : PLAN_VACANCY_MAKE }}</span>
      <span class="text-xs text-subtle">{{ line }}</span>
    </span>
    <LayoutPaveIcon name="chevronRight" class="size-3 shrink-0 text-subtle" />
  </button>
</template>
