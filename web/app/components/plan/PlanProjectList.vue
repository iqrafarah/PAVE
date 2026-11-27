<script setup lang="ts">
// On a project's page (iOS ProjectPlansList): the plans that belong to it, with how far each is. A click opens the plan.
const props = defineProps<{
  projectId: string;
}>();

const plans = usePlans();
const linked = computed(() => plans.plansInProject(props.projectId));

onMounted(() => {
  if (plans.state.value.status === 'idle') plans.load(true);
});
</script>

<template>
  <section v-if="linked.length" class="flex w-full flex-col gap-2">
    <h2 class="px-1 text-xs font-medium text-subtle">{{ linked.length === 1 ? PLAN_PROJECT_PLAN : PLAN_PROJECT_PLANS }}</h2>
    <NuxtLink
      v-for="plan in linked"
      :key="plan.id"
      :to="{ path: '/plan', query: { plan: plan.id } }"
      class="flex items-center gap-3 rounded-2xl border border-card-line bg-white p-3.5 hover:bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
    >
      <VaultIcon src="/images/plan/general.svg" class="size-4 shrink-0 text-brand" />
      <span class="flex min-w-0 flex-1 flex-col gap-1.5">
        <span translate="no" class="truncate text-sm font-semibold text-heading">{{ plan.name }}</span>
        <PlanProgressBar :progress="planProgress(plan)" :label="PLAN_PROGRESS_DONE(doneCount(plan), totalCount(plan))" />
        <span class="text-xs text-subtle">{{ PLAN_PROGRESS(doneCount(plan), totalCount(plan)) }} stappen afgerond</span>
      </span>
      <LayoutPaveIcon name="chevronRight" class="size-3 shrink-0 text-subtle" />
    </NuxtLink>
  </section>
</template>
