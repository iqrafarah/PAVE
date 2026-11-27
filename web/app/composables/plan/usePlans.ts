import type { AylaNewPlan, AylaPlanEdit, AylaPlanEditChange, AylaReply } from '~/types/ayla';
import type { Plan, PlanConversation, PlanStep, PlanStepStatus, PlanTemplate, PlanTemplateStep } from '~/types/plan';

/** What the user did with a proposal of Ayla to change a plan; none yet means the card still asks. */
export type PlanEditDecision = 'applied' | 'declined';

// Kept in this browser until account_state is there (docs/supabase-account-state.md, planEdit/decisions on iOS).
const EDIT_DECISIONS_KEY = 'pave-plan-edit-decisions';
// Proposals of Ayla being saved as a plan right now, so a second look at the same answer never makes it twice.
const makingFromAyla = new Set<string>();

// The user's plans (iOS PlanModel and SupabasePlanService): plans and plan_steps with the user's own session, so row
// level security decides. Every change shows at once and is saved right after with save_plan; when saving fails the
// change is undone and `problem` says so. The chats of a plan are the conversations whose plan_id points to it.

type PlansStatus = 'idle' | 'loading' | 'ready' | 'failed' | 'unavailable';

interface PlansState {
  plans: Plan[];
  status: PlansStatus;
  problem: string | null;
  /** A new chat on the start page belongs to this plan (and this step of it): "Bespreken met Ayla". */
  newChat: { planId: string; stepId: string | null; prompt: string | null } | null;
  /** The plan whose page should open Ayla's proposal at once: a plan just made "with Ayla". */
  proposesStepsFor: string | null;
  /** The chat whose plan is being saved from Ayla's answer right now. */
  makingPlanFor: string | null;
}

interface StepRow {
  id: string;
  position: number;
  title: string;
  summary: string;
  kind: string;
  status: string;
  completed_at: string | null;
  metadata: Record<string, unknown> | null;
}

interface PlanRow {
  id: string;
  name: string;
  goal: string;
  template_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
  plan_steps: StepRow[] | null;
}

interface ChatRow {
  id: string;
  title: string | null;
  plan_id: string;
  plan_step_id: string | null;
  created_at: string | null;
}

export interface ProposedSteps {
  steps: PlanTemplateStep[] | null;
  error: string | null;
}

const PLAN_SELECT =
  'id,name,goal,template_id,metadata,created_at,updated_at,completed_at,plan_steps(id,position,title,summary,kind,status,completed_at,metadata)';
/** A table, column or function that is not there means the migration has not run yet. */
const NOT_SET_UP = ['PGRST202', 'PGRST204', 'PGRST205', '42P01', '42703', '42883'];
const STATUSES: PlanStepStatus[] = ['upcoming', 'active', 'done', 'skipped'];

/** Metadata as text values; a number a flow stored becomes text too. */
function textValues(value: Record<string, unknown> | null) {
  const result: Record<string, string> = {};
  for (const [key, entry] of Object.entries(value ?? {})) {
    if (typeof entry === 'string') result[key] = entry;
    else if (typeof entry === 'number' || typeof entry === 'boolean') result[key] = String(entry);
  }
  return result;
}

function toPlan(row: PlanRow, chats: ChatRow[]): Plan {
  const conversations: PlanConversation[] = chats
    .filter((chat) => chat.plan_id === row.id)
    .map((chat) => ({ id: chat.id, title: chat.title ?? '', stepId: chat.plan_step_id, addedAt: chat.created_at ?? row.created_at }))
    .sort((a, b) => a.addedAt.localeCompare(b.addedAt));
  const steps: PlanStep[] = [...(row.plan_steps ?? [])]
    .sort((a, b) => a.position - b.position)
    .map((step) => ({
      id: step.id,
      title: step.title,
      summary: step.summary,
      kind: step.kind,
      status: STATUSES.includes(step.status as PlanStepStatus) ? (step.status as PlanStepStatus) : 'upcoming',
      conversationId: conversations.find((chat) => chat.stepId === step.id)?.id ?? null,
      completedAt: step.completed_at,
      metadata: textValues(step.metadata),
    }));
  return {
    id: row.id,
    name: row.name,
    goal: row.goal,
    templateId: row.template_id,
    steps,
    conversations,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completedAt: row.completed_at,
    metadata: textValues(row.metadata),
  };
}

export function usePlans() {
  const supabase = useUntypedSupabase();
  const vault = useVault();
  const state = useState<PlansState>('pave-plans', () => ({
    plans: [],
    status: 'idle',
    problem: null,
    newChat: null,
    proposesStepsFor: null,
    makingPlanFor: null,
  }));

  /** Plans still going, the most recently changed first. */
  const activePlans = computed(() =>
    state.value.plans.filter((plan) => !isPlanFinished(plan)).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt)),
  );
  /** Finished plans, the most recently finished first. */
  const finishedPlans = computed(() =>
    state.value.plans
      .filter(isPlanFinished)
      .sort((a, b) => (b.completedAt ?? b.updatedAt).localeCompare(a.completedAt ?? a.updatedAt)),
  );

  function find(id: string | null | undefined) {
    return state.value.plans.find((plan) => plan.id === id) ?? null;
  }

  function planForVacancy(vacancyId: string) {
    return state.value.plans.find((plan) => planVacancyId(plan) === vacancyId) ?? null;
  }

  function plansInProject(projectId: string) {
    return state.value.plans.filter((plan) => planProjectId(plan) === projectId);
  }

  /** A failure leaves what is shown as it is when `quietly`, such as after Ayla changed a step. */
  async function load(quietly = false) {
    if (state.value.status !== 'ready' && !quietly) state.value.status = 'loading';
    const [plans, chats] = await Promise.all([
      supabase.from('plans').select(PLAN_SELECT).order('updated_at', { ascending: false }),
      supabase.from('ayla_conversations').select('id,title,plan_id,plan_step_id,created_at').not('plan_id', 'is', null),
    ]);
    if (plans.error) {
      if (NOT_SET_UP.includes(plans.error.code ?? '')) state.value.status = 'unavailable';
      else if (!quietly) {
        state.value.status = state.value.status === 'ready' ? 'ready' : 'failed';
        state.value.problem = PLAN_LOAD_FAILED;
      }
      return;
    }
    const chatRows = chats.error ? [] : (chats.data as ChatRow[]);
    state.value.plans = (plans.data as PlanRow[]).map((row) => toPlan(row, chatRows));
    state.value.status = 'ready';
  }

  async function persist(plan: Plan) {
    const { error } = await supabase.rpc('save_plan', { p_plan: planPayload(plan) });
    if (!error) return true;
    if (NOT_SET_UP.includes(error.code ?? '')) {
      state.value.status = 'unavailable';
      state.value.problem = PLAN_NOT_AVAILABLE;
    } else {
      state.value.problem = PLAN_SAVE_FAILED;
    }
    return false;
  }

  /** Shows the change at once and saves it; when saving fails, the plan goes back to how it was. */
  async function change(planId: string, edit: (plan: Plan) => Plan) {
    const before = find(planId);
    if (!before) return false;
    const after = edit(before);
    if (after === before) return true;
    state.value.problem = null;
    state.value.plans = state.value.plans.map((plan) => (plan.id === planId ? after : plan));
    if (await persist(after)) return true;
    state.value.plans = state.value.plans.map((plan) => (plan.id === planId ? before : plan));
    return false;
  }

  async function create(name: string, goal: string, template: PlanTemplate) {
    const cleanName = cleanPlanName(name);
    if (!cleanName) return null;
    const plan = planFromTemplate(template, cleanName, cleanPlanGoal(goal));
    state.value.problem = null;
    state.value.plans = [plan, ...state.value.plans];
    if (await persist(plan)) {
      if (template.id === WITH_AYLA_TEMPLATE.id) state.value.proposesStepsFor = plan.id;
      return plan;
    }
    state.value.plans = state.value.plans.filter((entry) => entry.id !== plan.id);
    return null;
  }

  /** The plan for a vacancy: made once, opened after that. */
  async function planVacancy(vacancy: Parameters<typeof vacancyPlanTemplate>[0]) {
    const existing = planForVacancy(vacancy.id);
    if (existing) return existing;
    const template = vacancyPlanTemplate(vacancy);
    return create(template.name, template.goal, template);
  }

  function rename(planId: string, name: string, goal: string) {
    const cleanName = cleanPlanName(name);
    if (!cleanName) return Promise.resolve(false);
    return change(planId, (plan) => ({ ...plan, name: cleanName, goal: cleanPlanGoal(goal), updatedAt: new Date().toISOString() }));
  }

  /** The plan and its steps go; its chats stay, back in the normal list. Evidence is never touched. */
  async function remove(planId: string) {
    const before = state.value.plans;
    state.value.problem = null;
    state.value.plans = before.filter((plan) => plan.id !== planId);
    const { error } = await supabase.from('plans').delete().eq('id', planId);
    if (!error) return true;
    state.value.plans = before;
    state.value.problem = PLAN_SAVE_FAILED;
    return false;
  }

  const setStatus = (planId: string, stepId: string, status: PlanStepStatus) => change(planId, (plan) => setStepStatus(plan, stepId, status));
  const complete = (planId: string) => change(planId, completePlan);
  const reopen = (planId: string) => change(planId, reopenPlan);
  const addPlanSteps = (planId: string, steps: PlanTemplateStep[]) => change(planId, (plan) => addSteps(plan, steps));
  const editStep = (planId: string, step: Pick<PlanStep, 'id' | 'title' | 'summary' | 'kind'>) => change(planId, (plan) => updateStep(plan, step));
  const deleteStep = (planId: string, stepId: string) => change(planId, (plan) => removeStep(plan, stepId));
  const reorderStep = (planId: string, stepId: string, offset: -1 | 1) => change(planId, (plan) => moveStep(plan, stepId, offset));
  const detach = (planId: string, conversationId: string) => change(planId, (plan) => detachConversation(plan, conversationId));
  const setProject = (planId: string, projectId: string | null) => change(planId, (plan) => withProject(plan, projectId));

  /**
   * "Laat Ayla stappen voorstellen" (function ayla-plan): the plan's name and goal, the steps it has, the titles of
   * the evidence Ayla may see, and the vacancy it is about. Nothing goes into the plan until the user picks.
   */
  function proposalRequest(plan: Plan) {
    const allowed = vault.state.value.items.filter((item) => item.aylaAllowedAt && !item.archivedAt && item.status !== 'rejected');
    const skills = [...new Map(allowed.flatMap((item) => item.skills).map((skill) => [skill.toLowerCase(), skill])).values()].slice(0, 60);
    const job = planJob(plan);
    return {
      name: plan.name,
      goal: plan.goal,
      existing: plan.steps.map((step) => step.title),
      evidence: allowed.slice(0, 60).map((item) => ({ title: item.title, category: item.category, verified: item.status === 'verified' })),
      skills,
      ...(job ? { vacancy: job } : {}),
    };
  }

  async function proposeSteps(plan: Plan): Promise<ProposedSteps> {
    const { data, error } = await supabase.functions.invoke<{ steps?: { title?: string; summary?: string; kind?: string }[] }>('ayla-plan', {
      body: proposalRequest(plan),
    });
    if (error || !data?.steps) return { steps: null, error: PLAN_PROPOSAL_FAILED };
    const steps = data.steps
      .map((step) => ({ title: cleanPlanName(step.title ?? '') ?? '', summary: cleanPlanGoal(step.summary ?? ''), kind: step.kind || 'general' }))
      .filter((step) => step.title);
    return { steps, error: null };
  }

  /** The plan a chat belongs to. */
  function planOfConversation(conversationId: string | null | undefined) {
    if (!conversationId) return null;
    return state.value.plans.find((plan) => plan.conversations.some((chat) => chat.id === conversationId)) ?? null;
  }

  /** The plan of the open chat, or of the new chat that is about to start in a plan (iOS PlanModel.activePlan). */
  function planOfChat(conversationId: string | null | undefined) {
    return conversationId ? planOfConversation(conversationId) : find(state.value.newChat?.planId);
  }

  const completeStep = (planId: string) => change(planId, completeCurrentStep);

  /**
   * The plan the user asked Ayla for, with the chat in it, once per answer. A plan with the same name that is still
   * going is the plan she means: the chat joins it instead of a second plan beside it. Asked for a new plan in a plan's
   * chat, the chat moves to the new one.
   */
  async function createFromAyla(proposalId: string, made: AylaNewPlan, conversationId: string | null) {
    const name = cleanPlanName(made.name);
    if (!name || makingFromAyla.has(proposalId) || state.value.plans.some((plan) => isPlanFromProposal(plan, proposalId))) return;
    const same = state.value.plans.find((plan) => !isPlanFinished(plan) && isSamePlanName(plan.name, name));
    if (same) {
      if (conversationId && !planOfConversation(conversationId)) await change(same.id, (plan) => attachConversation(plan, conversationId));
      return;
    }
    const fromAyla = planFromAyla(made, proposalId);
    if (!fromAyla) return;
    makingFromAyla.add(proposalId);
    await saveWithChat(fromAyla, conversationId);
    makingFromAyla.delete(proposalId);
  }

  /** A new plan with the chat in it; a chat belongs to one plan, so it leaves the plan it was in. */
  async function saveWithChat(fresh: Plan, conversationId: string | null) {
    const plan = conversationId ? attachConversation(fresh, conversationId) : fresh;
    const old = planOfConversation(conversationId);
    state.value.problem = null;
    state.value.plans = [plan, ...state.value.plans];
    if (!(await persist(plan))) {
      state.value.plans = state.value.plans.filter((entry) => entry.id !== plan.id);
      return null;
    }
    if (old && conversationId) await change(old.id, (entry) => detachConversation(entry, conversationId));
    return plan;
  }

  /** A plan from the chat with these steps, with this chat in it. */
  function createForChat(name: string, goal: string, steps: PlanTemplateStep[], conversationId: string | null) {
    const cleanName = cleanPlanName(name);
    if (!cleanName) return Promise.resolve(null);
    const template: PlanTemplate = { id: WITH_AYLA_TEMPLATE.id, name: cleanName, summary: '', goal: '', steps };
    return saveWithChat(planFromTemplate(template, cleanName, cleanPlanGoal(goal)), conversationId);
  }

  /**
   * Asked for a plan while the server sent no createPlan (an Ayla function from before the web made plans): the
   * numbered steps of her answer become the plan, at once and with this chat in it, as createPlan would. Not for a chat
   * that already has a plan, nor for an answer without steps.
   */
  async function createFromAnswer(reply: AylaReply, conversationId: string | null, question: string) {
    if (!conversationId || planOfConversation(conversationId) || !asksForNewPlan(question)) return false;
    const steps = stepsFromAnswer(reply.text);
    if (!steps.length) return false;
    const name = planNameFromQuestion(question) || PLAN_TITLE;
    return Boolean(await createForChat(name, question, steps, conversationId));
  }

  /** "Plan toevoegen" in the chat: the chat goes into this plan, and out of the plan it was in. */
  async function addChatToPlan(planId: string, conversationId: string) {
    const old = planOfConversation(conversationId);
    if (old?.id === planId) return true;
    if (!(await change(planId, (plan) => attachConversation(plan, conversationId)))) return false;
    if (old) await change(old.id, (plan) => detachConversation(plan, conversationId));
    return true;
  }

  /**
   * After an answer of Ayla that just came in (iOS followsPlans): the plan she made, the step she changed at once, and
   * the plan of the chat loaded again, since the server may have changed it.
   */
  async function followReply(reply: AylaReply, conversationId: string | null, question: string) {
    if (state.value.status === 'idle') await load(true);
    if (state.value.status === 'unavailable') return;
    const action = reply.proposedAction;
    const makesPlan = (action?.kind === 'createPlan' && action.newPlan) || asksForNewPlan(question);
    if (makesPlan) state.value.makingPlanFor = conversationId;
    try {
      if (action?.kind === 'createPlan' && action.newPlan) {
        await createFromAyla(action.id, action.newPlan, conversationId);
        return;
      }
      if (await createFromAnswer(reply, conversationId, question)) return;
    } finally {
      if (makesPlan) state.value.makingPlanFor = null;
    }
    const changed = action?.kind === 'updatePlan' ? action.planStep : undefined;
    if (changed) {
      state.value.plans = state.value.plans.map((plan) => (plan.id === changed.planId ? setStepStatus(plan, changed.stepId, changed.status) : plan));
    }
    if (changed || planOfConversation(conversationId)) await load(true);
  }

  const editDecisions = useState<Record<string, PlanEditDecision>>('pave-plan-edit-decisions', () => ({}));

  function loadEditDecisions() {
    try {
      const saved: unknown = JSON.parse(localStorage.getItem(EDIT_DECISIONS_KEY) ?? '{}');
      if (saved && typeof saved === 'object') {
        const entries = Object.entries(saved).filter((entry): entry is [string, PlanEditDecision] => entry[1] === 'applied' || entry[1] === 'declined');
        editDecisions.value = { ...Object.fromEntries(entries), ...editDecisions.value };
      }
    } catch {
      // Not remembered: the card asks again after a reload.
    }
  }

  function decideEdit(editId: string, decision: PlanEditDecision | null) {
    const next = { ...editDecisions.value };
    if (decision) next[editId] = decision;
    else delete next[editId];
    editDecisions.value = next;
    try {
      localStorage.setItem(EDIT_DECISIONS_KEY, JSON.stringify(next));
    } catch {
      // Kept for this visit only.
    }
  }

  /** "Pas plan aan" with the changes the user kept; when saving fails, the card asks again. */
  async function applyEdit(edit: AylaPlanEdit, changes: AylaPlanEditChange[]) {
    decideEdit(edit.id, 'applied');
    const isSaved = await change(edit.planId, (plan) => applyPlanEdit(plan, changes));
    if (!isSaved) decideEdit(edit.id, null);
  }

  /**
   * A new chat with Ayla for this plan (and step): the start page opens with the plan's chip and, for a step, the
   * question ready. In a plan of a project, the chat starts in that project.
   */
  async function startChat(plan: Plan, step: PlanStep | null) {
    state.value.newChat = { planId: plan.id, stepId: step?.id ?? null, prompt: step ? PLAN_STEP_PROMPT(step.title) : null };
    const projectId = planProjectId(plan);
    if (projectId) useAylaProjects().state.value.newChatProjectId = projectId;
    await navigateTo('/');
  }

  return {
    state,
    activePlans,
    finishedPlans,
    find,
    planForVacancy,
    plansInProject,
    load,
    create,
    planVacancy,
    rename,
    remove,
    setStatus,
    complete,
    reopen,
    addPlanSteps,
    editStep,
    deleteStep,
    reorderStep,
    detach,
    setProject,
    proposalRequest,
    proposeSteps,
    startChat,
    planOfConversation,
    planOfChat,
    completeStep,
    createForChat,
    addChatToPlan,
    followReply,
    editDecisions,
    loadEditDecisions,
    decideEdit,
    applyEdit,
  };
}
