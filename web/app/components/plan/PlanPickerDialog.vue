<script setup lang="ts">
import type { Plan } from '~/types/plan';

// "Plan toevoegen" with the plus button (iOS PlanPickerSheet): puts the chat in one of your plans, or in a new one made
// as on the Plan page. A chat that has not begun yet starts in the plan with its first message. The plan's steps then
// show top left in the chat panel.
const props = defineProps<{
  conversationId: string | null;
}>();

const isOpen = defineModel<boolean>('open', { required: true });

const emit = defineEmits<{
  // "Nieuw plan": the chat opens the same form as the Plan page.
  newPlan: [];
}>();

const plans = usePlans();
const currentId = computed(() => plans.planOfChat(props.conversationId)?.id ?? null);

function subtitle(plan: Plan) {
  const step = currentStep(plan);
  if (step) return `${PLAN_STEP_NUMBER(currentNumber(plan), totalCount(plan))} · ${step.title}`;
  return isPlanFinished(plan) ? PLAN_FINISHED_SECTION : PLAN_NO_STEPS;
}

async function pick(plan: Plan) {
  if (props.conversationId) await plans.addChatToPlan(plan.id, props.conversationId);
  else plans.state.value.newChat = { planId: plan.id, stepId: null, prompt: null };
  isOpen.value = false;
}

async function leavePlan() {
  const planId = currentId.value;
  if (planId && props.conversationId) await plans.detach(planId, props.conversationId);
  else plans.state.value.newChat = null;
  isOpen.value = false;
}

watch(isOpen, (open) => {
  if (open && plans.state.value.status !== 'ready') plans.load(true);
});
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="PLAN_CHOOSE" width="narrow">
    <div class="flex flex-col gap-3 pb-2">
      <p class="text-sm text-subtle">{{ PLAN_CHOOSE_HINT }}</p>
      <p v-if="plans.state.value.status === 'loading' || plans.state.value.status === 'idle'" role="status" class="py-6 text-center text-sm text-subtle">
        {{ PLAN_LOADING }}
      </p>
      <p v-else-if="plans.state.value.status === 'unavailable'" class="py-6 text-center text-sm text-subtle">{{ PLAN_NOT_AVAILABLE }}</p>
      <ul v-else-if="plans.activePlans.value.length" class="flex flex-col gap-2">
        <li v-for="plan in plans.activePlans.value" :key="plan.id">
          <button
            type="button"
            :aria-current="plan.id === currentId ? 'true' : undefined"
            :class="plan.id === currentId ? 'border-brand bg-tint' : 'border-card-line bg-white hover:bg-surface'"
            class="flex w-full items-center gap-3 rounded-xl border p-3 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            @click="pick(plan)"
          >
            <PlanBadge :template-id="plan.templateId" />
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span translate="no" class="truncate text-sm font-semibold text-heading">{{ plan.name }}</span>
              <span translate="no" class="truncate text-xs text-subtle">{{ subtitle(plan) }}</span>
            </span>
            <span v-if="plan.id === currentId" class="shrink-0 text-xs font-semibold text-brand">{{ PLAN_CURRENT }}</span>
          </button>
        </li>
      </ul>
      <p v-if="plans.state.value.problem" role="alert" class="text-sm text-danger">{{ plans.state.value.problem }}</p>
      <div class="flex flex-wrap items-center justify-between gap-2">
        <button
          v-if="plans.state.value.status === 'ready'"
          type="button"
          class="flex min-h-11 items-center gap-1.5 rounded-field px-2 text-sm font-semibold text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
          @click="isOpen = false; emit('newPlan')"
        >
          <LayoutPaveIcon name="plus" class="size-3.5" />
          {{ PLAN_NEW }}
        </button>
        <button
          v-if="currentId"
          type="button"
          class="flex min-h-11 items-center rounded-field px-2 text-sm font-semibold text-danger hover:bg-status-rejected-surface focus-visible:outline-2 focus-visible:outline-brand"
          @click="leavePlan"
        >
          {{ PLAN_DETACH_CONVERSATION }}
        </button>
      </div>
    </div>
  </VaultSheet>
</template>
