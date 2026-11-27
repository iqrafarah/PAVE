<script setup lang="ts">
// Plan (iOS PlanScreen): your plans, the ones still going first and the finished ones under Voltooid, with "Nieuw plan".
// One plan opens on the same page (?plan=…), so the back button and a link from elsewhere work.
useHead({ title: `${PLAN_TITLE} - PAVE` });

const QUERY_KEY = 'plan';
const route = useRoute();
const router = useRouter();
const plans = usePlans();
const isCreating = ref(false);
const ids = { active: useId(), finished: useId() };

const state = computed(() => plans.state.value);
const openId = computed(() => (typeof route.query[QUERY_KEY] === 'string' ? route.query[QUERY_KEY] : null));
const opened = computed(() => plans.find(openId.value));
const hasPlans = computed(() => state.value.plans.length > 0);

function open(id: string | null) {
  const query = { ...route.query };
  if (id) query[QUERY_KEY] = id;
  else delete query[QUERY_KEY];
  router.push({ query });
}

onMounted(() => plans.load());
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col overflow-y-auto bg-surface">
    <header class="grid shrink-0 grid-cols-[1fr_auto_1fr] items-center gap-2 px-4 pt-7.5 sm:px-13.25">
      <div class="justify-self-start"><LayoutMenuLogo /></div>
      <div class="flex items-center justify-center gap-2">
        <AylaSlashIcon class="h-7.5 w-4.5" />
        <h1 class="text-3xl font-semibold text-brand max-sm:text-2xl">{{ PLAN_TITLE }}</h1>
      </div>
      <div class="justify-self-end">
        <button
          v-if="state.status === 'ready' && hasPlans && !opened"
          type="button"
          class="flex min-h-10 items-center gap-1.5 rounded-pill bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="isCreating = true"
        >
          <LayoutPaveIcon name="plus" class="size-3.5" />
          {{ PLAN_NEW }}
        </button>
      </div>
    </header>

    <div class="mx-auto flex w-full max-w-170 flex-1 flex-col gap-6 px-4 pb-10 pt-8 sm:px-6">
      <p v-if="state.problem" role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">{{ state.problem }}</p>

      <p v-if="state.status === 'idle' || state.status === 'loading'" role="status" class="py-10 text-center text-sm text-subtle">{{ PLAN_LOADING }}</p>
      <LayoutEmptyState v-else-if="state.status === 'unavailable'" icon="map" :title="PLAN_TITLE" :message="PLAN_NOT_AVAILABLE" class="py-16" />
      <div v-else-if="state.status === 'failed'" class="flex flex-col items-center gap-3 py-16 text-center">
        <p class="text-sm text-subtle">{{ PLAN_LOAD_FAILED }}</p>
        <button type="button" class="min-h-10 rounded-field px-3 text-sm font-semibold text-brand hover:bg-tint" @click="plans.load()">{{ PLAN_RETRY }}</button>
      </div>

      <PlanDetail v-else-if="opened" :key="opened.id" :plan="opened" @back="open(null)" />

      <div v-else-if="!hasPlans" class="flex flex-col items-center gap-5 py-12">
        <LayoutEmptyState icon="map" :title="PLAN_EMPTY_TITLE" :message="PLAN_EMPTY_MESSAGE" />
        <button
          type="button"
          class="flex min-h-11 items-center gap-1.5 rounded-pill bg-brand px-5 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="isCreating = true"
        >
          <LayoutPaveIcon name="plus" class="size-3.5" />
          {{ PLAN_NEW }}
        </button>
      </div>

      <template v-else>
        <section v-if="plans.activePlans.value.length" :aria-labelledby="ids.active" class="flex flex-col gap-2.5">
          <h2 :id="ids.active" class="px-1 text-sm font-semibold text-subtle">{{ PLAN_ACTIVE_SECTION }}</h2>
          <PlanCard v-for="plan in plans.activePlans.value" :key="plan.id" :plan="plan" @open="open(plan.id)" />
        </section>
        <section v-if="plans.finishedPlans.value.length" :aria-labelledby="ids.finished" class="flex flex-col gap-2.5">
          <h2 :id="ids.finished" class="px-1 text-sm font-semibold text-subtle">{{ PLAN_FINISHED_SECTION }}</h2>
          <PlanCard v-for="plan in plans.finishedPlans.value" :key="plan.id" :plan="plan" @open="open(plan.id)" />
        </section>
      </template>
    </div>

    <PlanEditorDialog v-model:open="isCreating" :plan="null" @created="open" />
  </div>
</template>
