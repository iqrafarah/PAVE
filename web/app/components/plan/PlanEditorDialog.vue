<script setup lang="ts">
import type { Plan, PlanTemplate } from '~/types/plan';

// "Nieuw plan" and "Plan aanpassen" (iOS PlanEditor): what to start with (an empty plan, steps from Ayla, or one of
// the templates), a name and a goal. Changing a plan has no templates, but can delete it.
const props = defineProps<{
  // Null: a new plan.
  plan: Plan | null;
}>();

const isOpen = defineModel<boolean>('open', { required: true });

const emit = defineEmits<{
  created: [planId: string];
  delete: [];
}>();

const plans = usePlans();
const template = ref<PlanTemplate>(EMPTY_PLAN_TEMPLATE);
const name = ref('');
const goal = ref('');
const isSaving = ref(false);
const nameError = ref(false);
const ids = { name: useId(), goal: useId(), goalHint: useId(), start: useId() };

const isNew = computed(() => props.plan === null);

watch(isOpen, (open) => {
  if (!open) return;
  template.value = EMPTY_PLAN_TEMPLATE;
  name.value = props.plan?.name ?? '';
  goal.value = props.plan?.goal ?? '';
  nameError.value = false;
});

/** A template fills in its name and goal, unless you already typed your own. */
function choose(next: PlanTemplate) {
  const previous = template.value;
  if (!name.value.trim() || name.value === previous.name) name.value = next.name;
  if (!goal.value.trim() || goal.value === previous.goal) goal.value = next.goal;
  template.value = next;
}

async function save() {
  if (!cleanPlanName(name.value)) {
    nameError.value = true;
    return;
  }
  isSaving.value = true;
  if (props.plan) {
    const isSaved = await plans.rename(props.plan.id, name.value, goal.value);
    isSaving.value = false;
    if (isSaved) isOpen.value = false;
    return;
  }
  const created = await plans.create(name.value, goal.value, template.value);
  isSaving.value = false;
  if (!created) return;
  isOpen.value = false;
  emit('created', created.id);
}

const field = 'w-full rounded-field border border-field-line bg-white px-3 text-sm font-medium text-heading outline-none focus:border-brand aria-invalid:border-danger';
const label = 'text-sm font-semibold text-heading';
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="isNew ? PLAN_NEW : PLAN_EDIT" width="narrow">
    <form id="plan-editor" class="flex flex-col gap-5 pb-2" novalidate @submit.prevent="save">
      <fieldset v-if="isNew" class="flex flex-col gap-2">
        <legend :id="ids.start" class="mb-2 text-sm font-semibold text-heading">{{ PLAN_START_LABEL }}</legend>
        <label
          v-for="option in PLAN_TEMPLATES"
          :key="option.id"
          :class="template.id === option.id ? 'border-brand bg-tint' : 'border-card-border bg-white hover:bg-surface'"
          class="flex cursor-pointer items-center gap-3 rounded-xl border px-3 py-2.5 has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand"
        >
          <input type="radio" name="plan-template" class="sr-only" :checked="template.id === option.id" @change="choose(option)" />
          <PlanBadge :template-id="option.id" />
          <span class="flex min-w-0 flex-1 flex-col gap-0.5">
            <span class="text-sm font-semibold text-heading">{{ planTemplateTitle(option) }}</span>
            <span class="text-xs text-subtle">{{ planTemplateSummary(option) }}</span>
          </span>
          <span v-if="option.steps.length" class="shrink-0 text-xs text-subtle">{{ PLAN_STEP_COUNT(option.steps.length) }}</span>
        </label>
      </fieldset>

      <div class="flex flex-col gap-1.5">
        <label :for="ids.name" :class="label">{{ PLAN_NAME_LABEL }}</label>
        <input
          :id="ids.name"
          v-model="name"
          type="text"
          :maxlength="PLAN_NAME_MAX"
          :placeholder="PLAN_NAME_PLACEHOLDER"
          :aria-invalid="nameError"
          :class="field"
          class="h-11"
          @input="nameError = false"
        />
      </div>

      <div class="flex flex-col gap-1.5">
        <label :for="ids.goal" :class="label">{{ PLAN_GOAL_LABEL }}</label>
        <textarea
          :id="ids.goal"
          v-model="goal"
          rows="3"
          :maxlength="PLAN_GOAL_MAX"
          :placeholder="PLAN_GOAL_PLACEHOLDER"
          :aria-describedby="ids.goalHint"
          :class="field"
          class="resize-y py-2.5"
        />
        <p :id="ids.goalHint" class="text-xs text-subtle">{{ PLAN_GOAL_HINT }}</p>
      </div>

      <button
        v-if="!isNew"
        type="button"
        class="flex min-h-10 items-center gap-2 self-start rounded-field px-2 text-sm font-semibold text-danger hover:bg-status-rejected-surface focus-visible:outline-2 focus-visible:outline-brand"
        @click="emit('delete')"
      >
        <LayoutPaveIcon name="trash" class="size-4" />
        {{ PLAN_DELETE }}
      </button>
    </form>

    <template #footer>
      <button
        type="submit"
        form="plan-editor"
        :disabled="isSaving"
        class="min-h-11 w-full rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
      >
        {{ isNew ? PLAN_CREATE : PLAN_SAVE }}
      </button>
    </template>
  </VaultSheet>
</template>
