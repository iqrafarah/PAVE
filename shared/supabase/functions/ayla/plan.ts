// The plan of a conversation: Ayla knows its goal, its steps and the step being worked on, and can mark a step done,
// skipped or as the one to work on now. See docs/ayla.md and migration 20261125130000_plans.sql.
import type { AylaReply } from './contract.ts'

export const PLAN_STEP_STATUSES = ['upcoming', 'active', 'done', 'skipped'] as const
export type PlanStepStatus = (typeof PLAN_STEP_STATUSES)[number]

export interface PlanStep { id: string; title: string; summary: string; kind: string; status: PlanStepStatus }
export interface PlanContext {
  id: string
  name: string
  goal: string
  steps: PlanStep[]
  stepId?: string
  /** The vacancy the plan was made for, when it was. */
  vacancy?: { title: string; company: string; missing: string[] }
}

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
  /** Free room of the apps; a plan made for a vacancy keeps which one and what the user still misses for it. */
  metadata?: Record<string, unknown> | null
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
    .select('plan_id, plan_step_id, plans(id, name, goal, metadata, plan_steps(id, position, title, summary, kind, status))')
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
  const vacancy = planVacancy(row.metadata)
  return { id: row.id, name: row.name, goal: row.goal ?? '', steps, ...(stepId ? { stepId } : {}), ...(vacancy ? { vacancy } : {}) }
}

/** The vacancy a plan was made for, as the apps keep it in the plan's metadata (PlanVacancy on iOS). */
function planVacancy(metadata: Record<string, unknown> | null | undefined): PlanContext['vacancy'] {
  const text = (key: string) => (typeof metadata?.[key] === 'string' ? (metadata[key] as string).trim() : '')
  const title = text('vacancyTitle')
  if (!title) return undefined
  return { title: title.slice(0, 160), company: text('vacancyCompany').slice(0, 120), missing: text('vacancyMissing').split('\u001f').map((skill) => skill.trim()).filter(Boolean).slice(0, 8) }
}

/** What each kind of step is, and where in PAVE it is done, so she can point there. */
const KIND_WORDS: Record<string, string> = {
  conversation: 'uitpraten of oefenen met jou',
  research: 'uitzoeken, of vacatures bekijken onder Vacatures',
  evidence: 'bewijs in de Kluis zetten',
  verification: 'bewijs laten verifiëren, bij het bewijsstuk in de Kluis',
  document: 'cv of brief schrijven',
  profile: 'delen bij Profiel',
  contact: 'iemand mailen of bellen',
  action: 'iets doen buiten PAVE',
  reflection: 'terugkijken',
  milestone: 'een moment dat je haalt',
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
    `${index + 1}. [${STATUS_WORDS[step.status]}] ${clean(step.title)}${step.summary.trim() ? ` — ${clean(step.summary)}` : ''}${KIND_WORDS[step.kind] ? ` (soort: ${KIND_WORDS[step.kind]})` : ''}`
  )
  const vacancy = plan.vacancy
    ? `Het plan is gemaakt voor de vacature "${clean(plan.vacancy.title)}"${plan.vacancy.company ? ` bij ${clean(plan.vacancy.company)}` : ''}.${plan.vacancy.missing.length ? ` Wat de gebruiker daarvoor volgens de app nog mist: ${plan.vacancy.missing.map(clean).join(', ')}.` : ''} Help de gebruiker bij elke stap met díe vacature voor ogen.`
    : null
  const focus = chosen >= 0 ? chosen : current
  return [
    `## Het plan van dit gesprek`,
    `Dit gesprek hoort bij het plan "${clean(plan.name)}" van de gebruiker.${plan.goal.trim() ? ` Het doel, in de woorden van de gebruiker: "${clean(plan.goal)}".` : ''}`,
    ...(vacancy ? [vacancy] : []),
    lines.length ? `De stappen:\n${lines.join('\n')}` : 'Het plan heeft nog geen stappen: de gebruiker kan bij Plan zelf stappen toevoegen of jou stappen laten voorstellen ("Laat Ayla stappen voorstellen").',
    'Zo help je bij dit plan: (1) Noem eerst wat het doel echt vraagt: diploma, opleiding, bevoegdheid, certificaat of ervaring, zo concreet als je eerlijk weet (bij "docent ICT" bijvoorbeeld een lerarenopleiding of een pedagogisch-didactisch getuigschrift naast een ICT-opleiding), en zeg het erbij als het per school of regio verschilt. (2) Leg dat naast het bewijs uit de kluis dat je ziet en de bronnen van het project: noem bij titel wat er al is en wat ontbreekt. Zie je de kluis niet en hangt je antwoord ervan af, vraag dan één keer om erin te kijken (askVault, met als doel dat je wilt zien wat de gebruiker al heeft voor dit plan); vraag het niet opnieuw als de gebruiker nee zei. (3) Geef dan de eerstvolgende kleine handeling met een termijn, en zeg bij welke stap van het plan die hoort. Ontbreekt er een stap in het plan, stel dan voor hem toe te voegen (op de iPhone met addPlanStep, nadat de gebruiker ja zei). Geen algemene tips die voor iedereen gelden.',
    'Bij een stap hoort vaak een plek in PAVE (zie "soort"). Zeg waar de gebruiker het doet, en help met de inhoud: wat erin moet, wat de gebruiker al heeft in de kluis die je mag zien, en wat de eerstvolgende kleine handeling is. Is een stap te groot, deel hem dan in dit gesprek op in twee of drie kleinere handelingen; de stappen van het plan zelf verander je niet.',
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

/** The kinds of step the apps know; another kind shows as a general step, so the model only picks from these. */
export const PLAN_STEP_KINDS = ['general', 'conversation', 'research', 'evidence', 'verification', 'document', 'action', 'reflection', 'milestone', 'profile', 'contact'] as const
const MIN_NEW_STEPS = 2
const MAX_NEW_STEPS = 8

/** A new plan the user asked for ("maak een plan"): a name, the goal and the steps, in the order to do them. */
export const NEW_PLAN_SCHEMA = {
  type: ['object', 'null'],
  additionalProperties: false,
  required: ['name', 'goal', 'steps'],
  properties: {
    name: { type: 'string' },
    goal: { type: 'string' },
    steps: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'summary', 'kind'],
        properties: { title: { type: 'string' }, summary: { type: 'string' }, kind: { type: 'string', enum: [...PLAN_STEP_KINDS] } },
      },
    },
  },
} as const

export const NEW_PLAN_RULE = 'newPlan: vraagt de gebruiker je een plan te maken (zoals "maak een plan", "help me een plan maken om ..."), vul dan newPlan. name: kort, hooguit 80 tekens, zoals "Stage vinden in Utrecht". goal: het doel in één zin, in de woorden van de gebruiker. steps: 3 tot 6 stappen in de volgorde waarin de gebruiker ze doet, elk met een korte title (hooguit 80 tekens, een korte opdracht zoals "Je cv bijwerken"), een summary van één zin en het kind dat het best past: conversation (uitpraten of oefenen met jou), research (uitzoeken, vacatures bekijken), evidence (bewijs in de kluis), verification (laten verifiëren), document (cv of brief), profile (delen), contact (iemand mailen of bellen), action (iets doen buiten PAVE), reflection (terugkijken), milestone (een moment dat je haalt) of general. Gebruik wat je uit dit gesprek, de kluis en je notities weet. Zeg in text kort dat het plan klaarstaat bovenaan dit gesprek, en noem de eerste stap. Weet je nog niet waar het plan over gaat, vraag dan eerst naar het doel en zet newPlan op null. Hoort dit gesprek al bij een plan, maak dan alleen een nieuw plan als de gebruiker uitdrukkelijk om een nieuw of ander plan vraagt. Heeft een plan onder "Zo staat de app nu" hetzelfde soort doel (ook als plaats of details anders zijn), vraag dan één keer of de gebruiker een nieuw plan wil of dat plan wil openen (intent askUser, newPlan null). Kiest de gebruiker een nieuw plan, vul dan meteen newPlan en vraag het niet opnieuw. Vul je newPlan, schrijf de stappen dan niet ook uit in text: alleen de eerste. Anders is newPlan null.'

/** Where the apps cannot make a plan, the model never proposes one. */
export const NO_NEW_PLAN_RULE = 'newPlan is altijd null.'

export interface NewPlan { name: string; goal: string; steps: { title: string; summary: string; kind: string }[] }

/** A checked new plan, or undefined when the model gave nothing usable. Lengths follow the plans tables. */
export function newPlanProposal(raw: unknown, id: string, now: Date): NonNullable<AylaReply['proposedAction']> | undefined {
  if (!raw || typeof raw !== 'object') return undefined
  const value = raw as { name?: unknown; goal?: unknown; steps?: unknown }
  const name = line(value.name, 80)
  if (!name) return undefined
  const steps = (Array.isArray(value.steps) ? value.steps : [])
    .map((step) => {
      const { title, summary, kind } = (step ?? {}) as { title?: unknown; summary?: unknown; kind?: unknown }
      const cleanTitle = line(title, 80)
      if (!cleanTitle) return undefined
      return {
        title: cleanTitle,
        summary: line(summary, 280) ?? '',
        kind: (PLAN_STEP_KINDS as readonly unknown[]).includes(kind) ? kind as string : 'general',
      }
    })
    .filter((step): step is NewPlan['steps'][number] => !!step)
    .slice(0, MAX_NEW_STEPS)
  if (steps.length < MIN_NEW_STEPS) return undefined
  return {
    id,
    kind: 'createPlan',
    summary: `Plan "${name}" gemaakt`,
    expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString(),
    newPlan: { name, goal: line(value.goal, 280) ?? '', steps },
  }
}

function line(raw: unknown, max: number): string | undefined {
  if (typeof raw !== 'string') return undefined
  const value = raw.replace(/\s+/g, ' ').trim()
  return value ? value.slice(0, max).trim() : undefined
}

/** The user's words on one line, without quotes that could end the quote around them. */
function clean(text: string): string {
  return text.replace(/\s+/g, ' ').replace(/"/g, "'").trim().slice(0, 280)
}
