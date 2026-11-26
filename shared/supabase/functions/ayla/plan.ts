// The plan of a conversation: Ayla knows its goal, its steps and the step being worked on, and can mark a step done,
// skipped or as the one to work on now. See docs/ayla.md and migration 20261125130000_plans.sql.
import type { AylaReply } from './contract.ts'

export const PLAN_STEP_STATUSES = ['upcoming', 'active', 'done', 'skipped'] as const
export type PlanStepStatus = (typeof PLAN_STEP_STATUSES)[number]

export interface PlanStep { id: string; title: string; summary: string; kind: string; status: PlanStepStatus }
export interface PlanContext { id: string; name: string; goal: string; steps: PlanStep[]; stepId?: string }

/** What the model may say about the plan: a step by its number in the list, and what it now is. */
export const PLAN_STEP_SCHEMA = {
  type: ['object', 'null'],
  additionalProperties: false,
  required: ['step', 'status'],
  properties: { step: { type: 'integer' }, status: { type: 'string', enum: ['active', 'done', 'skipped'] } },
} as const

const STATUS_WORDS: Record<PlanStepStatus, string> = {
  upcoming: 'nog te doen',
  active: 'nu bezig',
  done: 'afgerond',
  skipped: 'overgeslagen',
}

interface PlanRow {
  id: string
  name: string
  goal: string
  plan_steps: { id: string; position: number; title: string; summary: string; kind: string; status: string }[] | null
}

// deno-lint-ignore no-explicit-any
type Client = { from: (table: string) => any; rpc: (fn: string, args: Record<string, unknown>) => any }

/**
 * The plan of a conversation, or of the plan a new conversation starts in. Row level security only shows the user's
 * own plans; before the plans migration the query fails and there is none.
 */
export async function loadPlan(supabase: Client, conversationId: string): Promise<PlanContext | undefined> {
  const { data, error } = await supabase
    .from('ayla_conversations')
    .select('plan_id, plan_step_id, plans(id, name, goal, plan_steps(id, position, title, summary, kind, status))')
    .eq('id', conversationId)
    .maybeSingle()
  const row = error ? null : (data as { plan_step_id: string | null; plans: PlanRow | null } | null)
  if (!row?.plans) return undefined
  return toPlan(row.plans, row.plan_step_id ?? undefined)
}

/** Whether the plan exists for this user; false too before the migration. */
export async function planExists(supabase: Client, planId: string): Promise<boolean> {
  const { data, error } = await supabase.from('plans').select('id').eq('id', planId).maybeSingle()
  return !error && !!data
}

export function toPlan(row: PlanRow, stepId?: string): PlanContext {
  const steps = [...(row.plan_steps ?? [])]
    .sort((a, b) => a.position - b.position)
    .map((step) => ({
      id: step.id,
      title: step.title,
      summary: step.summary ?? '',
      kind: step.kind ?? 'general',
      status: (PLAN_STEP_STATUSES as readonly string[]).includes(step.status) ? step.status as PlanStepStatus : 'upcoming',
    }))
  return { id: row.id, name: row.name, goal: row.goal ?? '', steps, ...(stepId ? { stepId } : {}) }
}

/** Marks a step in the database, with the user's own rights; the plan stays in order (`set_plan_step_status`). */
export function stepUpdater(supabase: Client) {
  return async (stepId: string, status: PlanStepStatus): Promise<boolean> => {
    const { error } = await supabase.rpc('set_plan_step_status', { p_step_id: stepId, p_status: status })
    return !error
  }
}

/**
 * The plan in the prompt: its goal and every step with a number, its status and what it is about. The user's own
 * words for the plan are marked as such: they steer what she helps with, never her rules.
 */
export function planLayer(plan: PlanContext | undefined): string | null {
  if (!plan) return null
  const current = plan.steps.findIndex((step) => step.status === 'active')
  const chosen = plan.stepId ? plan.steps.findIndex((step) => step.id === plan.stepId) : -1
  const lines = plan.steps.map((step, index) =>
    `${index + 1}. [${STATUS_WORDS[step.status]}] ${clean(step.title)}${step.summary.trim() ? ` — ${clean(step.summary)}` : ''}`
  )
  const focus = chosen >= 0 ? chosen : current
  return [
    `## Het plan van dit gesprek`,
    `Dit gesprek hoort bij het plan "${clean(plan.name)}" van de gebruiker.${plan.goal.trim() ? ` Het doel, in de woorden van de gebruiker: "${clean(plan.goal)}".` : ''}`,
    lines.length ? `De stappen:\n${lines.join('\n')}` : 'Het plan heeft nog geen stappen.',
    focus >= 0
      ? `Help de gebruiker vooral met stap ${focus + 1} ("${clean(plan.steps[focus].title)}"), tenzij de gebruiker iets anders vraagt. Verwijs naar de stappen bij hun naam, niet bij hun nummer.`
      : 'Alle stappen zijn afgerond of overgeslagen: help de gebruiker terugkijken of een volgende stap kiezen.',
    'planStep: zegt de gebruiker dat een stap klaar is, of is het in dit gesprek zeker dat een stap af is, zet dan planStep op het nummer van die stap met status "done". Wil de gebruiker een stap overslaan: "skipped". Wil de gebruiker met een andere stap verder: "active". Alleen voor een stap uit deze lijst die nog niet zo staat, en alleen als de gebruiker het zegt of het zeker is; vraag het anders eerst. Anders is planStep null. Zeg in text kort wat je in het plan hebt bijgewerkt.',
  ].join('\n')
}

/** Without a plan, the model never touches one. */
export const NO_PLAN_RULE = 'planStep is altijd null: dit gesprek hoort niet bij een plan.'

/** The step the model chose, if it is real, changes something and is allowed; otherwise nothing. */
export function planChange(raw: unknown, plan: PlanContext | undefined): { step: PlanStep; status: PlanStepStatus } | undefined {
  if (!plan || typeof raw !== 'object' || raw === null) return undefined
  const { step: number, status } = raw as { step?: unknown; status?: unknown }
  if (typeof number !== 'number' || !Number.isInteger(number)) return undefined
  if (status !== 'active' && status !== 'done' && status !== 'skipped') return undefined
  const step = plan.steps[number - 1]
  if (!step || step.status === status) return undefined
  return { step, status }
}

/** What the apps get about a step that changed, so the plan shows it at once. */
export function planProposal(plan: PlanContext, change: { step: PlanStep; status: PlanStepStatus }, id: string, now: Date): NonNullable<AylaReply['proposedAction']> {
  const words = change.status === 'done' ? 'afgerond' : change.status === 'skipped' ? 'overgeslagen' : 'nu bezig'
  return {
    id,
    kind: 'updatePlan',
    summary: `Stap "${change.step.title}" ${words}`,
    expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString(),
    planStep: { planId: plan.id, stepId: change.step.id, status: change.status },
  }
}

/** The user's words on one line, without quotes that could end the quote around them. */
function clean(text: string): string {
  return text.replace(/\s+/g, ' ').replace(/"/g, "'").trim().slice(0, 280)
}
