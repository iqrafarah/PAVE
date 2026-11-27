import type { AylaNewPlan, AylaPlanEditChange, Vacancy } from '~/types/ayla';
import type { Plan, PlanStep, PlanStepStatus, PlanTemplate, PlanTemplateStep } from '~/types/plan';
import { PLAN_VACANCY_STEPS } from './planMessages';

// What a plan does (iOS PAVECore PavePlan and PlanVacancy; keep them the same). Every function returns a new plan, so
// a change can be undone when saving fails.

export const PLAN_NAME_MAX = 80;
export const PLAN_GOAL_MAX = 280;
const VACANCY_ID = 'vacancyID';
const VACANCY_TITLE = 'vacancyTitle';
const VACANCY_COMPANY = 'vacancyCompany';
const VACANCY_SUMMARY = 'vacancySummary';
const VACANCY_MISSING = 'vacancyMissing';
const MISSING_SEPARATOR = '\u001F';
const PROJECT_ID = 'projectID';

/** Ids are UUIDs in lower case, as the database gives them back. */
export function newPlanId() {
  return crypto.randomUUID().toLowerCase();
}

/** A name someone typed, tidied up; null when nothing is left. */
export function cleanPlanName(text: string) {
  const words = text.split(/\s+/).filter(Boolean).join(' ');
  return words ? words.slice(0, PLAN_NAME_MAX) : null;
}

export function cleanPlanGoal(text: string) {
  return text.trim().slice(0, PLAN_GOAL_MAX);
}

function now() {
  return new Date().toISOString();
}

export function newStep(step: PlanTemplateStep, status: PlanStepStatus = 'upcoming'): PlanStep {
  return {
    id: newPlanId(),
    title: step.title,
    summary: step.summary,
    kind: step.kind,
    status,
    conversationId: null,
    completedAt: null,
    metadata: { ...(step.metadata ?? {}) },
  };
}

// Progress -----------------------------------------------------------------------------------------------------------

/** A skipped step is left out everywhere, so "Stap 3 van 5", "2 van 5 afgerond" and the bar always agree. */
export function countedSteps(plan: Plan) {
  return plan.steps.filter((step) => step.status !== 'skipped');
}

export function doneCount(plan: Plan) {
  return countedSteps(plan).filter((step) => step.status === 'done').length;
}

export function totalCount(plan: Plan) {
  return countedSteps(plan).length;
}

export function planProgress(plan: Plan) {
  const total = totalCount(plan);
  return total === 0 ? 0 : doneCount(plan) / total;
}

function hasStepsLeft(plan: Plan) {
  return plan.steps.some((step) => step.status === 'upcoming' || step.status === 'active');
}

/** Finished: marked so, or every step is done or skipped (and there is at least one). */
export function isPlanFinished(plan: Plan) {
  return plan.completedAt !== null || (plan.steps.length > 0 && !hasStepsLeft(plan));
}

export function currentStep(plan: Plan) {
  return plan.steps.find((step) => step.status === 'active') ?? null;
}

/** The place of the current step among the steps that count, from 1; with every step done, the number of steps. */
export function currentNumber(plan: Plan) {
  const counted = countedSteps(plan);
  const index = counted.findIndex((step) => step.status === 'active');
  return index >= 0 ? index + 1 : counted.length;
}

// Keeping a plan in order --------------------------------------------------------------------------------------------

/**
 * One active step while anything is left to do, and it is the first one not done when none was chosen. A plan is
 * finished when nothing is left, and goes on again when a step is reopened.
 */
export function normalizePlan(plan: Plan): Plan {
  const steps = plan.steps.map((step) => ({ ...step }));
  const actives = steps.filter((step) => step.status === 'active');
  for (const extra of actives.slice(1)) extra.status = 'upcoming';
  if (!actives.length) {
    const next = steps.find((step) => step.status === 'upcoming');
    if (next) next.status = 'active';
  }
  const next = { ...plan, steps };
  if (hasStepsLeft(next)) next.completedAt = null;
  else if (steps.length && next.completedAt === null) next.completedAt = next.updatedAt;
  return next;
}

/** A new plan from a template: the first step is the one to work on. */
export function planFromTemplate(template: PlanTemplate, name: string, goal: string): Plan {
  const at = now();
  return normalizePlan({
    id: newPlanId(),
    name,
    goal,
    templateId: template.steps.length ? template.id : null,
    steps: template.steps.map((step) => newStep(step)),
    conversations: [],
    createdAt: at,
    updatedAt: at,
    completedAt: null,
    metadata: { ...(template.metadata ?? {}) },
  });
}

/** Changes a step's status: one step at a time is active, and when it is done the next one becomes active. */
export function setStepStatus(plan: Plan, stepId: string, status: PlanStepStatus): Plan {
  const target = plan.steps.find((step) => step.id === stepId);
  if (!target || target.status === status) return plan;
  const at = now();
  const steps = plan.steps.map((step) => {
    if (step.id === stepId) return { ...step, status, completedAt: status === 'done' ? at : null };
    if (status === 'active' && step.status === 'active') return { ...step, status: 'upcoming' as const };
    return step;
  });
  return normalizePlan({ ...plan, steps, updatedAt: at });
}

export function addSteps(plan: Plan, added: PlanTemplateStep[]): Plan {
  if (!added.length) return plan;
  return normalizePlan({ ...plan, steps: [...plan.steps, ...added.map((step) => newStep(step))], updatedAt: now() });
}

export function removeStep(plan: Plan, stepId: string): Plan {
  return normalizePlan({ ...plan, steps: plan.steps.filter((step) => step.id !== stepId), updatedAt: now() });
}

/** A step's title, summary or kind changed; its status stays. */
export function updateStep(plan: Plan, changed: Pick<PlanStep, 'id' | 'title' | 'summary' | 'kind'>): Plan {
  return {
    ...plan,
    steps: plan.steps.map((step) => (step.id === changed.id ? { ...step, title: changed.title, summary: changed.summary, kind: changed.kind } : step)),
    updatedAt: now(),
  };
}

/** One place up (-1) or down (1). */
export function moveStep(plan: Plan, stepId: string, offset: -1 | 1): Plan {
  const index = plan.steps.findIndex((step) => step.id === stepId);
  const target = index + offset;
  if (index < 0 || target < 0 || target >= plan.steps.length) return plan;
  const steps = [...plan.steps];
  [steps[index], steps[target]] = [steps[target]!, steps[index]!];
  return normalizePlan({ ...plan, steps, updatedAt: now() });
}

/** "Voltooien": every step still to do is done, and the plan is finished. */
export function completePlan(plan: Plan): Plan {
  const at = now();
  const steps = plan.steps.map((step) =>
    step.status === 'upcoming' || step.status === 'active' ? { ...step, status: 'done' as const, completedAt: at } : step,
  );
  return { ...plan, steps, completedAt: at, updatedAt: at };
}

/** "Weer openen": the plan goes on, from the last step that was done. */
export function reopenPlan(plan: Plan): Plan {
  const steps = plan.steps.map((step) => ({ ...step }));
  if (!steps.some((step) => step.status === 'upcoming' || step.status === 'active')) {
    const last = [...steps].reverse().find((step) => step.status === 'done');
    if (last) {
      last.status = 'active';
      last.completedAt = null;
    }
  }
  return { ...plan, steps, completedAt: null, updatedAt: now() };
}

/** "Afronden" in the chat: the step you are on is done and the next one becomes the step to work on. */
export function completeCurrentStep(plan: Plan): Plan {
  const current = currentStep(plan);
  return current ? setStepStatus(plan, current.id, 'done') : plan;
}

/** The step goes just before another one, or at the end without one (iOS PavePlan.moveStep(id:before:)). */
function moveStepBefore(plan: Plan, stepId: string, beforeId: string | null): Plan {
  const step = plan.steps.find((entry) => entry.id === stepId);
  if (!step || stepId === beforeId) return plan;
  const others = plan.steps.filter((entry) => entry.id !== stepId);
  const target = beforeId ? others.findIndex((entry) => entry.id === beforeId) : -1;
  const steps = target >= 0 ? [...others.slice(0, target), step, ...others.slice(target)] : [...others, step];
  return normalizePlan({ ...plan, steps, updatedAt: now() });
}

/** Right after a step, or at the start (null); after a step that is gone, at the end. */
function placeStepAfter(plan: Plan, stepId: string, afterId: string | null): Plan {
  const others = plan.steps.filter((entry) => entry.id !== stepId);
  if (afterId === null) return moveStepBefore(plan, stepId, others[0]?.id ?? null);
  const index = others.findIndex((entry) => entry.id === afterId);
  return moveStepBefore(plan, stepId, index >= 0 ? (others[index + 1]?.id ?? null) : null);
}

/**
 * Ayla's proposed changes, as far as the user kept them (iOS PavePlan.apply): new steps where she put them, steps
 * taken out (never a done one), steps moved. A step that is gone meanwhile is left alone.
 */
export function applyPlanEdit(plan: Plan, changes: AylaPlanEditChange[]): Plan {
  let next = plan;
  for (const change of changes) {
    if (change.op === 'add') {
      const title = cleanPlanName(change.title);
      if (!title) continue;
      const step = newStep({ title, summary: change.why, kind: change.kind || 'general' });
      next = placeStepAfter(normalizePlan({ ...next, steps: [...next.steps, step], updatedAt: now() }), step.id, change.afterStepId ?? null);
    } else if (change.op === 'remove') {
      const isOpen = next.steps.some((step) => step.id === change.stepId && step.status !== 'done');
      if (change.stepId && isOpen) next = removeStep(next, change.stepId);
    } else if (change.stepId && next.steps.some((step) => step.id === change.stepId)) {
      next = placeStepAfter(next, change.stepId, change.afterStepId ?? null);
    }
  }
  return next;
}

/** The chat belongs to the plan (and to a step of it), as save_plan stores it. */
export function attachConversation(plan: Plan, conversationId: string, title = '', stepId: string | null = null): Plan {
  const known = plan.conversations.find((chat) => chat.id === conversationId);
  const conversations = known
    ? plan.conversations.map((chat) => (chat.id === conversationId ? { ...chat, title: title || chat.title, stepId: stepId ?? chat.stepId } : chat))
    : [...plan.conversations, { id: conversationId, title, stepId, addedAt: now() }];
  const steps = plan.steps.map((step) => (step.id === stepId && !step.conversationId ? { ...step, conversationId } : step));
  return { ...plan, conversations, steps, updatedAt: now() };
}

/** Two names for the same plan: case, accents, spaces and punctuation do not count (iOS PlanModel.sameName). */
export function isSamePlanName(a: string, b: string) {
  const key = (text: string) => text.toLocaleLowerCase('nl').normalize('NFD').replace(/[^\p{L}\p{N}]/gu, '');
  return key(a) === key(b);
}

const AYLA_PROPOSAL = 'aylaProposal';
const AYLA_TEMPLATE_ID = 'ayla';

/** The plan made from what Ayla wrote, once per proposal: the plan keeps the id of her proposal. */
export function isPlanFromProposal(plan: Plan, proposalId: string) {
  return plan.metadata[AYLA_PROPOSAL] === proposalId;
}

export function planFromAyla(made: AylaNewPlan, proposalId: string): Plan | null {
  const name = cleanPlanName(made.name);
  if (!name) return null;
  const steps = made.steps
    .map((step) => ({ title: cleanPlanName(step.title) ?? '', summary: cleanPlanGoal(step.summary), kind: step.kind || 'general' }))
    .filter((step) => step.title);
  const template: PlanTemplate = { id: AYLA_TEMPLATE_ID, name, summary: '', goal: '', steps, metadata: { [AYLA_PROPOSAL]: proposalId } };
  return planFromTemplate(template, name, cleanPlanGoal(made.goal));
}

export function detachConversation(plan: Plan, conversationId: string): Plan {
  return {
    ...plan,
    conversations: plan.conversations.filter((chat) => chat.id !== conversationId),
    steps: plan.steps.map((step) => (step.conversationId === conversationId ? { ...step, conversationId: null } : step)),
    updatedAt: now(),
  };
}

// Project ------------------------------------------------------------------------------------------------------------

/** The project in Ayla this plan belongs to: new chats of the plan start in it. */
export function planProjectId(plan: Plan) {
  return plan.metadata[PROJECT_ID] ?? null;
}

export function withProject(plan: Plan, projectId: string | null): Plan {
  const metadata = { ...plan.metadata };
  if (projectId) metadata[PROJECT_ID] = projectId;
  else delete metadata[PROJECT_ID];
  return { ...plan, metadata, updatedAt: now() };
}

// A plan for a vacancy -----------------------------------------------------------------------------------------------

export function planVacancyId(plan: Plan) {
  return plan.metadata[VACANCY_ID] ?? null;
}

export function planVacancyTitle(plan: Plan) {
  return plan.metadata[VACANCY_TITLE] ?? null;
}

/** The vacancy as Ayla's step proposal gets it. */
export function planJob(plan: Plan) {
  const title = plan.metadata[VACANCY_TITLE];
  if (!title) return null;
  return {
    title,
    company: plan.metadata[VACANCY_COMPANY] ?? '',
    summary: plan.metadata[VACANCY_SUMMARY],
    missing: plan.metadata[VACANCY_MISSING]?.split(MISSING_SEPARATOR).filter(Boolean) ?? [],
  };
}

/**
 * The steps towards applying for this vacancy: read it, work on what is missing, evidence, CV and letter, share, and
 * practise the talk. All of them can be changed afterwards.
 */
export function vacancyPlanTemplate(vacancy: Vacancy): PlanTemplate {
  const metadata: Record<string, string> = { [VACANCY_ID]: vacancy.id, [VACANCY_TITLE]: vacancy.title, [VACANCY_COMPANY]: vacancy.company };
  const missing = vacancy.skillGap.map((gap) => gap.skill).filter(Boolean).slice(0, 8);
  if (missing.length) metadata[VACANCY_MISSING] = missing.join(MISSING_SEPARATOR);
  const steps: PlanTemplateStep[] = [
    { title: PLAN_VACANCY_STEPS.read, summary: PLAN_VACANCY_STEPS.readSummary, kind: 'research', metadata: { [VACANCY_ID]: vacancy.id } },
    ...vacancy.skillGap
      .filter((gap) => gap.skill)
      .slice(0, 3)
      .map((gap) => ({
        title: PLAN_VACANCY_STEPS.workOn(gap.skill).slice(0, PLAN_NAME_MAX),
        summary: cleanPlanGoal(gap.requirement ? PLAN_VACANCY_STEPS.asks(gap.requirement) : PLAN_VACANCY_STEPS.missing),
        kind: 'action',
      })),
    { title: PLAN_VACANCY_STEPS.evidence, summary: PLAN_VACANCY_STEPS.evidenceSummary, kind: 'evidence' },
    { title: PLAN_VACANCY_STEPS.write, summary: PLAN_VACANCY_STEPS.writeSummary, kind: 'document', metadata: { [VACANCY_ID]: vacancy.id } },
    { title: PLAN_VACANCY_STEPS.share, summary: PLAN_VACANCY_STEPS.shareSummary(vacancy.company), kind: 'profile', metadata: { [VACANCY_ID]: vacancy.id } },
    { title: PLAN_VACANCY_STEPS.practise, summary: PLAN_VACANCY_STEPS.practiseSummary, kind: 'conversation', metadata: { [VACANCY_ID]: vacancy.id } },
  ];
  return {
    id: 'vacancy',
    name: `${vacancy.title} bij ${vacancy.company}`.slice(0, PLAN_NAME_MAX),
    summary: PLAN_VACANCY_STEPS.templateSummary,
    goal: cleanPlanGoal(PLAN_VACANCY_STEPS.goal(vacancy.title, vacancy.company)),
    steps,
    metadata,
  };
}

// Saving -------------------------------------------------------------------------------------------------------------

/** The plan as save_plan reads it (the JSON of iOS PavePlan). */
export function planPayload(plan: Plan) {
  return {
    id: plan.id,
    name: plan.name,
    goal: plan.goal,
    templateID: plan.templateId,
    createdAt: plan.createdAt,
    completedAt: plan.completedAt,
    metadata: plan.metadata,
    steps: plan.steps.map((step) => ({
      id: step.id,
      title: step.title,
      summary: step.summary,
      kind: step.kind,
      status: step.status,
      completedAt: step.completedAt,
      metadata: step.metadata,
    })),
    conversations: plan.conversations.map((chat) => ({ id: chat.id, stepID: chat.stepId })),
  };
}
