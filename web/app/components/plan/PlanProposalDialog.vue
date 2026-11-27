<script setup lang="ts">
import type { Plan, PlanTemplateStep } from '~/types/plan';

// "Laat Ayla stappen voorstellen" (iOS PlanStepProposalSheet): Ayla reads the plan's name and goal, the titles of the
// evidence she may see and the vacancy it is about, and proposes steps. Nothing goes into the plan until you pick
// which ones and add them. "Andere stappen voorstellen" asks again.
const props = defineProps<{
  plan: Plan | null;
}>();

const isOpen = defineModel<boolean>('open', { required: true });

const emit = defineEmits<{
  add: [steps: PlanTemplateStep[]];
}>();

const plans = usePlans();
const vault = useVault();
const steps = ref<PlanTemplateStep[] | null>(null);
const chosen = ref<number[]>([]);
const failed = ref(false);
let round = 0;

const request = computed(() => (props.plan ? plans.proposalRequest(props.plan) : null));
const reads = computed(() => planProposalReads(request.value?.evidence.length ?? 0, Boolean(request.value && 'vacancy' in request.value)));

async function load() {
  const plan = props.plan;
  if (!plan) return;
  const current = ++round;
  failed.value = false;
  steps.value = null;
  if (vault.state.value.status !== 'ready') await vault.load();
  const result = await plans.proposeSteps(plan);
  if (current !== round) return;
  if (result.error || !result.steps) {
    failed.value = true;
    return;
  }
  steps.value = result.steps;
  chosen.value = result.steps.map((_, index) => index);
}

function toggle(index: number) {
  chosen.value = chosen.value.includes(index) ? chosen.value.filter((entry) => entry !== index) : [...chosen.value, index];
}

function add() {
  if (!steps.value) return;
  emit('add', steps.value.filter((_, index) => chosen.value.includes(index)));
  isOpen.value = false;
}

watch(isOpen, (open) => {
  if (open) load();
  else round++;
});
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="PLAN_PROPOSAL_TITLE" width="narrow">
    <div class="flex flex-col gap-4 pb-2">
      <p class="text-xs text-subtle">{{ reads }}</p>
      <template v-if="failed">
        <p role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">{{ PLAN_PROPOSAL_FAILED }}</p>
        <button type="button" class="min-h-11 rounded-field bg-field-line px-4 text-sm font-medium text-heading hover:bg-tile" @click="load">
          {{ PLAN_PROPOSAL_AGAIN }}
        </button>
      </template>
      <p v-else-if="steps === null" role="status" class="flex min-h-30 items-center justify-center gap-2 text-sm text-subtle">
        <span class="size-4 animate-spin rounded-full border-2 border-brand border-t-transparent motion-reduce:animate-none" aria-hidden="true" />
        {{ PLAN_PROPOSAL_THINKING }}
      </p>
      <p v-else-if="!steps.length" class="text-sm text-heading">{{ PLAN_PROPOSAL_EMPTY }}</p>
      <ul v-else class="flex flex-col divide-y divide-card-line rounded-2xl border border-card-border bg-white">
        <li v-for="(step, index) in steps" :key="index">
          <label class="flex cursor-pointer items-start gap-3 p-3.5 hover:bg-surface has-focus-visible:outline-2 has-focus-visible:-outline-offset-2 has-focus-visible:outline-brand">
            <input type="checkbox" :checked="chosen.includes(index)" class="mt-0.5 size-4.5 shrink-0 accent-brand" @change="toggle(index)" />
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span translate="no" class="text-sm font-semibold text-heading">{{ step.title }}</span>
              <span v-if="step.summary" translate="no" class="text-xs text-subtle">{{ step.summary }}</span>
              <span class="text-xs font-medium text-brand">{{ planKindTitle(step.kind) }}</span>
            </span>
            <VaultIcon :src="planStepIcon(step.kind)" class="mt-1 size-4 shrink-0 text-subtle" />
          </label>
        </li>
      </ul>
    </div>

    <template v-if="steps && steps.length && !failed" #footer>
      <div class="flex w-full flex-col items-center gap-1">
        <button
          type="button"
          :disabled="!chosen.length"
          class="min-h-11 w-full rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
          @click="add"
        >
          {{ PLAN_PROPOSAL_ADD(chosen.length) }}
        </button>
        <button type="button" class="min-h-11 rounded-md px-2 text-sm font-semibold text-brand hover:underline" @click="load">
          {{ PLAN_PROPOSAL_OTHERS }}
        </button>
      </div>
    </template>
  </VaultSheet>
</template>
