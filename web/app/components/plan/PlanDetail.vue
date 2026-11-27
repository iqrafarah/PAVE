<script setup lang="ts">
import type { Plan, PlanStep } from '~/types/plan';

// The page of one plan (iOS PlanDetailView): its goal and progress, all steps, its project and its chats with Ayla.
// From here you go on with Ayla (the latest chat of the plan, or a new one for the step you are on) and change the
// steps yourself. Every step has its own menu: talk it through, finish, skip, go there in PAVE, change it.
const props = defineProps<{
  plan: Plan;
}>();

const emit = defineEmits<{
  back: [];
}>();

const plans = usePlans();
const projects = useAylaProjects();
const chats = useAylaChats();
const isEditing = ref(false);
const isProposing = ref(false);
const isAddingStep = ref(false);
const editedStep = ref<PlanStep | null>(null);
const isEditingStep = ref(false);
const deleteRef = useTemplateRef<{ open: () => void }>('confirmDelete');
const ids = { steps: useId(), chats: useId(), project: useId() };

const total = computed(() => totalCount(props.plan));
const progressLabel = computed(() => PLAN_PROGRESS_DONE(doneCount(props.plan), total.value));
const hasSkipped = computed(() => props.plan.steps.some((step) => step.status === 'skipped'));
const isFinished = computed(() => isPlanFinished(props.plan));
const projectId = computed(() => planProjectId(props.plan));
const projectChoice = computed({
  get: () => projectId.value ?? '',
  set: (value: string) => chooseProject(value || null),
});
/** Chats that were deleted elsewhere are not shown. */
const planChats = computed(() => {
  const known = chats.state.value.conversations;
  const isComplete = chats.state.value.status === 'ready';
  return [...props.plan.conversations]
    .reverse()
    .filter((chat) => !isComplete || known.some((entry) => entry.id === chat.id))
    .map((chat) => ({ ...chat, title: known.find((entry) => entry.id === chat.id)?.title || chat.title }));
});
const deleteMessage = computed(() => (props.plan.conversations.length ? PLAN_DELETE_BODY_CHATS(props.plan.conversations.length) : PLAN_DELETE_BODY));

function stepOptions(step: PlanStep, index: number) {
  const options = [{ id: 'discuss', label: PLAN_DISCUSS_STEP, icon: planStepIcon('conversation') }];
  if (step.status !== 'done') options.push({ id: 'done', label: PLAN_MARK_DONE, icon: '/images/vault/status-verified.svg' });
  if (step.status !== 'active') options.push({ id: 'active', label: PLAN_MARK_ACTIVE, icon: planStepIcon('action') });
  if (step.status === 'done' || step.status === 'skipped') options.push({ id: 'upcoming', label: PLAN_MARK_UPCOMING, icon: '/images/vault/icons/ArrowPath.svg' });
  if (step.status !== 'skipped' && step.status !== 'done') options.push({ id: 'skipped', label: PLAN_MARK_SKIPPED, icon: '/images/vault/icons/ArrowPath.svg' });
  const place = planKindPlace(step.kind);
  if (place) options.push({ id: 'place', label: place.label, icon: planStepIcon(step.kind) });
  if (step.conversationId) options.push({ id: 'chat', label: PLAN_OPEN_STEP_CHAT, icon: planStepIcon('conversation') });
  if (index > 0) options.push({ id: 'up', label: PLAN_MOVE_UP, icon: '/images/vault/icons/ArrowLeft.svg' });
  if (index < props.plan.steps.length - 1) options.push({ id: 'down', label: PLAN_MOVE_DOWN, icon: '/images/vault/icons/ArrowLeft.svg' });
  options.push({ id: 'edit', label: PLAN_EDIT_STEP, icon: '/images/vault/icons/Pencil.svg' });
  return options;
}

function stepAction(step: PlanStep, action: string) {
  const planId = props.plan.id;
  switch (action) {
    case 'discuss':
      plans.startChat(props.plan, step);
      break;
    case 'done':
    case 'active':
    case 'upcoming':
    case 'skipped':
      plans.setStatus(planId, step.id, action);
      break;
    case 'place':
      navigateTo(planKindPlace(step.kind)!.path);
      break;
    case 'chat':
      navigateTo(`/ayla/${step.conversationId}`);
      break;
    case 'up':
    case 'down':
      plans.reorderStep(planId, step.id, action === 'up' ? -1 : 1);
      break;
    case 'edit':
      editedStep.value = step;
      isEditingStep.value = true;
      break;
  }
}

/** The round mark before a step: done, or back to do. */
function toggleDone(step: PlanStep) {
  plans.setStatus(props.plan.id, step.id, step.status === 'done' ? 'upcoming' : 'done');
}

/** Back to the latest chat of the plan, or a new one for the step you are on. */
function resume() {
  const latest = planChats.value[0];
  if (latest) navigateTo(`/ayla/${latest.id}`);
  else plans.startChat(props.plan, currentStep(props.plan));
}

/** A plan in a project: its chats move there too, so Ayla uses the project's instructions and sources. */
async function chooseProject(next: string | null) {
  const isSaved = await plans.setProject(props.plan.id, next);
  if (!isSaved || !next) return;
  for (const chat of props.plan.conversations) await projects.moveChat(chat.id, next);
}

function saveStep(step: { title: string; summary: string; kind: string }) {
  if (editedStep.value) plans.editStep(props.plan.id, { id: editedStep.value.id, ...step });
  else plans.addPlanSteps(props.plan.id, [step]);
}

async function deletePlan() {
  isEditing.value = false;
  if (await plans.remove(props.plan.id)) emit('back');
}

function addStep() {
  editedStep.value = null;
  isAddingStep.value = true;
}

// A plan just made "with Ayla" opens her proposal as soon as its page shows.
onMounted(() => {
  if (projects.state.value.status === 'idle') projects.load();
  if (chats.state.value.status === 'idle') chats.load();
  if (plans.state.value.proposesStepsFor === props.plan.id) {
    plans.state.value.proposesStepsFor = null;
    isProposing.value = true;
  }
});

const softButton =
  'flex min-h-11 items-center justify-center gap-2 rounded-field bg-tint px-4 text-sm font-medium text-brand hover:bg-brand/15 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const primaryButton =
  'flex min-h-11 items-center justify-center gap-2 rounded-field bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const linkButton =
  'flex min-h-11 items-center gap-2 rounded-field px-2 text-sm font-semibold text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand';
const sectionTitle = 'text-base font-semibold text-heading';
const panel = 'rounded-2xl border border-card-line bg-white';
</script>

<template>
  <article class="flex flex-col gap-7">
    <div class="flex items-center justify-between gap-2">
      <button type="button" :class="linkButton" @click="emit('back')">
        <LayoutPaveIcon name="arrowLeft" class="size-4" />
        {{ PLAN_BACK }}
      </button>
      <VaultMenu
        :label="PLAN_MORE"
        align="right"
        :options="[
          { id: 'edit', label: PLAN_RENAME, icon: '/images/vault/icons/Pencil.svg' },
          { id: 'add', label: PLAN_ADD_STEP, icon: '/images/vault/icons/Plus.svg' },
          { id: 'propose', label: PLAN_PROPOSE_STEPS, icon: planStepIcon('conversation') },
          isFinished
            ? { id: 'reopen', label: PLAN_REOPEN, icon: '/images/vault/icons/ArrowPath.svg' }
            : { id: 'complete', label: PLAN_COMPLETE, icon: '/images/vault/status-verified.svg' },
          { id: 'delete', label: PLAN_DELETE, icon: '/images/vault/icons/Trash.svg' },
        ]"
        toggle-class="flex size-10 items-center justify-center rounded-pill text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
        @select="
          (id) => {
            if (id === 'edit') isEditing = true;
            else if (id === 'add') addStep();
            else if (id === 'propose') isProposing = true;
            else if (id === 'reopen') plans.reopen(plan.id);
            else if (id === 'complete') plans.complete(plan.id);
            else if (id === 'delete') deleteRef?.open();
          }
        "
      >
        <template #label>
          <LayoutPaveIcon name="ellipsis" class="size-5" />
          <span class="sr-only">{{ PLAN_MORE }}</span>
        </template>
      </VaultMenu>
    </div>

    <header class="flex flex-col gap-4">
      <div class="flex items-start gap-3.5">
        <PlanBadge :template-id="plan.templateId" size="large" />
        <div class="flex min-w-0 flex-col gap-1.5">
          <h2 translate="no" class="font-heading text-2xl font-semibold text-heading">{{ plan.name }}</h2>
          <p v-if="plan.goal" translate="no" class="text-sm font-medium text-subtle">{{ plan.goal }}</p>
        </div>
      </div>
      <div v-if="total" class="flex flex-col gap-2">
        <PlanProgressBar :progress="planProgress(plan)" :label="progressLabel" />
        <p class="text-xs text-subtle">
          {{ progressLabel }}<template v-if="hasSkipped"> · {{ PLAN_SKIPPED_NOTE }}</template>
        </p>
      </div>
      <p v-if="isFinished && total" class="text-sm font-medium text-brand">{{ PLAN_FINISHED }}</p>
      <div class="flex flex-wrap gap-2.5">
        <button v-if="isFinished" type="button" :class="softButton" @click="plans.reopen(plan.id)">{{ PLAN_REOPEN }}</button>
        <template v-else>
          <button type="button" :class="primaryButton" @click="resume">{{ PLAN_RESUME }}</button>
          <button type="button" :class="softButton" @click="plans.startChat(plan, currentStep(plan))">{{ PLAN_NEW_CONVERSATION }}</button>
        </template>
      </div>
    </header>

    <section v-if="projects.state.value.projects.length" :aria-labelledby="ids.project" class="flex flex-col gap-2">
      <h3 :id="ids.project" :class="sectionTitle">{{ PLAN_PROJECT }}</h3>
      <label class="relative flex h-11 items-center rounded-field border border-field-line bg-white pl-3 pr-8 has-focus-visible:border-brand">
        <span class="sr-only">{{ PLAN_LINK_PROJECT }}</span>
        <select v-model="projectChoice" class="w-full cursor-pointer appearance-none bg-transparent text-sm font-medium text-heading outline-none">
          <option value="">{{ PLAN_NO_PROJECT }}</option>
          <option v-for="project in projects.state.value.projects" :key="project.id" :value="project.id" translate="no">{{ project.name }}</option>
        </select>
        <LayoutIcon name="chevronDown" class="pointer-events-none absolute right-3 size-3.5 text-subtle" />
      </label>
      <p class="text-xs text-subtle">{{ projectId ? PLAN_LINKED_PROJECT_HINT : PLAN_LINK_PROJECT_HINT }}</p>
    </section>

    <section :aria-labelledby="ids.steps" class="flex flex-col gap-3">
      <h3 :id="ids.steps" :class="sectionTitle">{{ PLAN_STEPS }}</h3>
      <p v-if="!plan.steps.length" class="text-sm text-subtle">{{ PLAN_NO_STEPS }}</p>
      <ol v-else :class="panel" class="flex flex-col divide-y divide-card-line">
        <li v-for="(step, index) in plan.steps" :key="step.id" class="flex items-start gap-3 px-4 py-3.5">
          <button
            type="button"
            :aria-label="`${step.title}: ${PLAN_STATUS[step.status]}`"
            :aria-pressed="step.status === 'done'"
            :class="{
              'border-brand bg-brand text-white': step.status === 'done',
              'border-brand bg-tint': step.status === 'active',
              'border-field-line bg-white': step.status === 'upcoming',
              'border-dashed border-field-line bg-white': step.status === 'skipped',
            }"
            class="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full border-2 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
            @click="toggleDone(step)"
          >
            <LayoutIcon v-if="step.status === 'done'" name="check" class="size-3.5" />
            <span v-else-if="step.status === 'active'" class="size-2 rounded-full bg-brand" />
          </button>
          <div class="flex min-w-0 flex-1 flex-col gap-0.5">
            <p
              translate="no"
              :class="[step.status === 'skipped' ? 'text-subtle line-through' : 'text-heading', step.status === 'active' ? 'font-semibold' : 'font-medium']"
              class="text-sm"
            >
              {{ step.title }}
            </p>
            <p v-if="step.summary" translate="no" class="text-xs text-subtle">{{ step.summary }}</p>
            <p class="flex items-center gap-1.5 text-xs text-subtle">
              <VaultIcon :src="planStepIcon(step.kind)" :class="step.status === 'active' ? 'text-brand' : 'text-subtle'" class="size-3.5" />
              {{ planKindTitle(step.kind) }}
              <template v-if="step.status === 'active' || step.status === 'skipped'"> · {{ PLAN_STATUS[step.status] }}</template>
            </p>
          </div>
          <VaultMenu
            :label="PLAN_STEP_ACTIONS(step.title)"
            align="right"
            :options="stepOptions(step, index)"
            toggle-class="flex size-9 shrink-0 items-center justify-center rounded-lg text-subtle hover:bg-surface hover:text-heading focus-visible:outline-2 focus-visible:outline-brand"
            @select="stepAction(step, $event)"
          >
            <template #label>
              <LayoutPaveIcon name="ellipsis" class="size-4.5" />
              <span class="sr-only">{{ PLAN_STEP_ACTIONS(step.title) }}</span>
            </template>
          </VaultMenu>
        </li>
      </ol>
      <div class="flex flex-wrap gap-1">
        <button type="button" :class="linkButton" @click="addStep">
          <LayoutPaveIcon name="plus" class="size-3.5" />
          {{ PLAN_ADD_STEP }}
        </button>
        <button type="button" :class="linkButton" @click="isProposing = true">
          <AylaSlashIcon :blocks="4" class="h-3.5 w-2" />
          {{ PLAN_PROPOSE_STEPS }}
        </button>
      </div>
    </section>

    <section :aria-labelledby="ids.chats" class="flex flex-col gap-3">
      <h3 :id="ids.chats" :class="sectionTitle">{{ PLAN_CONVERSATIONS }}</h3>
      <p v-if="!planChats.length" class="text-sm text-subtle">{{ PLAN_NO_CONVERSATIONS }}</p>
      <ul v-else :class="panel" class="flex flex-col divide-y divide-card-line">
        <li v-for="(chat, index) in planChats" :key="chat.id" class="flex items-center gap-2 pr-2">
          <NuxtLink
            :to="`/ayla/${chat.id}`"
            class="flex min-h-14 min-w-0 flex-1 items-center gap-3 px-4 py-2 hover:bg-surface focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand"
          >
            <LayoutPaveIcon name="chat" class="size-4 shrink-0 text-brand" />
            <span class="flex min-w-0 flex-col">
              <span translate="no" class="truncate text-sm font-medium text-heading">{{ chat.title || PLAN_UNTITLED_CONVERSATION(planChats.length - index) }}</span>
              <span v-if="chat.stepId" translate="no" class="truncate text-xs text-subtle">{{ plan.steps.find((step) => step.id === chat.stepId)?.title }}</span>
            </span>
          </NuxtLink>
          <button
            type="button"
            :title="PLAN_DETACH_CONVERSATION"
            class="flex size-9 shrink-0 items-center justify-center rounded-lg text-subtle hover:bg-surface hover:text-danger focus-visible:outline-2 focus-visible:outline-brand"
            @click="plans.detach(plan.id, chat.id)"
          >
            <LayoutPaveIcon name="xMark" class="size-3.5" />
            <span class="sr-only">{{ PLAN_DETACH_CONVERSATION }}: {{ chat.title }}</span>
          </button>
        </li>
      </ul>
    </section>

    <PlanEditorDialog v-model:open="isEditing" :plan="plan" @delete="isEditing = false; deleteRef?.open()" />
    <PlanStepDialog v-model:open="isAddingStep" :step="null" @save="saveStep" />
    <PlanStepDialog
      v-model:open="isEditingStep"
      :step="editedStep"
      @save="saveStep"
      @delete="editedStep && plans.deleteStep(plan.id, editedStep.id)"
    />
    <PlanProposalDialog v-model:open="isProposing" :plan="plan" @add="plans.addPlanSteps(plan.id, $event)" />
    <LayoutConfirmSheet ref="confirmDelete" :title="PLAN_DELETE_QUESTION" :message="deleteMessage" :confirm-label="PLAN_DELETE" @confirm="deletePlan" />
  </article>
</template>
