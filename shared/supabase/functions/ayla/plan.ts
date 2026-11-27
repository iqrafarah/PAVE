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
/**
 * The apps that make a plan from her answer (newPlan) and show the card with changes to a plan (planEdit): the iPhone
 * and the web. The Watch has no room for either.
 */
export function makesPlans(device: 'phone' | 'watch' | 'web'): boolean {
  return device === 'phone' || device === 'web'
}

/** What she can do for a plan, per device: only what really happens there. */
const PLAN_TOOLS: Record<'phone' | 'watch' | 'web', string> = {
  phone: 'Je kunt opleidingen en cursussen zoeken (educationSearch), feiten opzoeken met bronnen (webLookup: toelatingseisen, kosten, open dagen), een datum in de agenda zetten (addToCalendar), een mail opstellen aan een school of persoon (writeMail), in de kluis kijken (askVault), stappen toevoegen, afvinken, een deadline geven of verplaatsen, bewijs aan een stap koppelen en vacatures zoeken. Vraagt een stap om uitzoeken welke opleiding of cursus past, zoek dan meteen met educationSearch in plaats van het alleen aan te bieden.',
  watch: 'Op het horloge kun je feiten opzoeken (webLookup), stappen toevoegen of afvinken en een datum voor de agenda klaarzetten op de iPhone (addToCalendar). Opleidingen of vacatures zoeken en mails opstellen gaan op de iPhone: zeg dat.',
  web: 'Op de website kun je opleidingen zoeken (educationSearch), feiten opzoeken (webLookup), in de kluis kijken (askVault), een stap afvinken (planStep) en stappen toevoegen, weghalen of verplaatsen voorstellen (planEdit). Een agenda en mail zijn er op de website niet: zeg dan wat de gebruiker zelf kan doen.',
}

/** How she works through the steps with the user, per device: the iPhone has her actions, the web only the card. */
const PLAN_STEPS_WORK: Record<'phone' | 'watch' | 'web', string> = {
  phone: 'Je loopt samen met de gebruiker door de stappen en houdt het doel in het oog: stappen toevoegen, weghalen of verplaatsen stel je voor met planEdit, en de gebruiker beslist op de kaart. Vraagt de gebruiker zelf om één stap toe te voegen, doe dan addPlanStep. Hernoemen doe je alleen als de gebruiker erom vraagt.',
  watch: 'Een stap toevoegen mag als de gebruiker ja zegt (addPlanStep); bestaande stappen hernoem of verwijder je alleen als de gebruiker erom vraagt.',
  web: 'Je loopt samen met de gebruiker door de stappen en houdt het doel in het oog: stappen toevoegen, weghalen of verplaatsen stel je voor met planEdit, ook als de gebruiker zelf om één stap vraagt, en de gebruiker beslist op de kaart. Hernoemen doet de gebruiker zelf bij Plan.',
}

export function planLayer(plan: PlanContext | undefined, device: 'phone' | 'watch' | 'web' = 'phone'): string | null {
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
    lines.length ? `De stappen (wat de gebruiker nog moet doen of al deed; een stap is geen bewijs: staat in de kluis al wat een open stap oplevert, zoals een stap "Rijbewijs halen" terwijl de kluis een rijbewijs heeft, dan is die stap eigenlijk al klaar):\n${lines.join('\n')}` : 'Het plan heeft nog geen stappen: de gebruiker kan bij Plan zelf stappen toevoegen of jou stappen laten voorstellen ("Laat Ayla stappen voorstellen").',
    'Zo help je bij dit plan, in hooguit vier zinnen: (1) wat het doel vraagt, (2) wat de kluis en de bronnen van het project al hebben, bij titel, (3) wat ontbreekt, (4) één handeling met een termijn, en bij welke stap van het plan die hoort. Noem bij (1) alleen soorten bewijs die je zeker weet (zoals een lerarenopleiding of een pedagogisch-didactisch getuigschrift, een ICT-opleiding, een certificaat); noem geen niveaus, graden, aantallen jaren of vrijstellingen, en zeg dat de school, de werkgever of de opleiding de precieze eisen bepaalt. Vraagt de gebruiker wat er nodig is of wat ontbreekt en zie je de kluis niet, noem dan in één zin wat het doel meestal vraagt en vraag in hetzelfde antwoord met askVault om in de kluis te kijken; de vergelijking volgt na de toestemming. Vraag dat niet opnieuw als de gebruiker nee zei. De handeling is concreet, zoals "Zoek deze week op de site van een lerarenopleiding welke vooropleiding ze vragen en schrijf op wat je nog mist."; niet "doe onderzoek" of "kijk wat bij je past". Schrijf in text geen eigen stappenlijst: je helpt bij de stap van nu' + (makesPlans(device) ? ', en wat er aan het plan moet veranderen stel je voor met planEdit' : '') + '. ' + PLAN_TOOLS[device] + ' Zegt de gebruiker nee op een voorstel, stel dan het volgende uit dit rijtje voor in plaats van een open vraag.',
    'Bij een stap hoort vaak een plek in PAVE (zie "soort"). Zeg waar de gebruiker het doet, en help met de inhoud: wat erin moet, wat de gebruiker al heeft in de kluis die je mag zien, en wat de eerstvolgende kleine handeling is. Is een stap te groot, deel hem dan in dit gesprek op in twee of drie kleinere handelingen. ' + PLAN_STEPS_WORK[device] + ' Staat er al een stap met dezelfde inhoud, noem die en voeg niets toe.',
    focus >= 0
      ? `Help de gebruiker vooral met stap ${focus + 1} ("${clean(plan.steps[focus].title)}"), tenzij de gebruiker iets anders vraagt. Verwijs naar de stappen bij hun naam, niet bij hun nummer.`
      : 'Alle stappen zijn afgerond of overgeslagen: help de gebruiker terugkijken of een volgende stap kiezen.',
    'planStep: zegt de gebruiker dat een stap klaar is, of is het in dit gesprek zeker dat een stap af is, zet dan planStep op het nummer van die stap met status "done". Wil de gebruiker een stap overslaan: "skipped". Wil de gebruiker met een andere stap verder: "active". Alleen voor een stap uit deze lijst die nog niet zo staat, en alleen als de gebruiker het zegt of het zeker is; vraag het anders eerst. Anders is planStep null. Zeg in text kort wat je in het plan hebt bijgewerkt. Rond je een stap af, noem dan in hetzelfde antwoord de volgende stap en begin die meteen met één concrete vraag of handeling: zo lopen jullie samen naar het doel.',
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

export const NEW_PLAN_RULE = 'newPlan: vraagt de gebruiker je een plan te maken (zoals "maak een plan", "help me een plan maken om ..."), vul dan newPlan. name: kort, hooguit 80 tekens, zoals "Stage vinden in Utrecht". goal: het doel in één zin, in de woorden van de gebruiker. steps: 3 tot 6 stappen in de volgorde waarin de gebruiker ze doet, elk met een korte title (hooguit 80 tekens, een korte opdracht zoals "Je cv bijwerken"), een summary van één zin en het kind dat het best past: conversation (uitpraten of oefenen met jou), research (uitzoeken, vacatures bekijken), evidence (bewijs in de kluis), verification (laten verifiëren), document (cv of brief), profile (delen), contact (iemand mailen of bellen), action (iets doen buiten PAVE), reflection (terugkijken), milestone (een moment dat je haalt) of general. Gebruik wat je uit dit gesprek, de kluis en je notities weet. Zeg in text kort dat het plan klaarstaat bovenaan dit gesprek, en noem de eerste stap. Weet je nog niet waar het plan over gaat, vraag dan eerst naar het doel en zet newPlan op null. Hoort dit gesprek al bij een plan, maak dan alleen een nieuw plan als de gebruiker uitdrukkelijk om een nieuw of ander plan vraagt. Vul je newPlan, schrijf de stappen dan niet ook uit in text: alleen de eerste. Anders is newPlan null.'

/**
 * Only the iPhone lists the plans it has ("Zo staat de app nu") and can delete one (deletePlan); the web makes a plan
 * with the same name part of the plan that is there.
 */
export const NEW_PLAN_LISTED_RULE = 'Heeft een plan onder "Zo staat de app nu" hetzelfde soort doel (ook als plaats of details anders zijn), vraag dan één keer of de gebruiker een nieuw plan wil of dat plan wil openen (intent askUser, newPlan null), behalve als de gebruiker al zegt dat oude plan te willen verwijderen of opnieuw te beginnen: zet dan deletePlan voor het oude plan in actions, en vul newPlan als het nieuwe doel al bekend is; vraag het niet in text. Kiest de gebruiker een nieuw plan, vul dan meteen newPlan en vraag het niet opnieuw.'

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

/**
 * Changes Ayla proposes to the plan of the conversation, so it reaches its goal: steps to add, steps that can go, and
 * steps in another order. Steps are named by their number in the list; `after` is the step a new or moved step comes
 * after (0: at the start). Nothing changes before the user taps "Pas plan aan" on the card.
 */
export const PLAN_EDIT_SCHEMA = {
  type: ['object', 'null'],
  additionalProperties: false,
  required: ['changes'],
  properties: {
    changes: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['op', 'step', 'title', 'kind', 'after', 'why'],
        properties: {
          op: { type: 'string', enum: ['add', 'remove', 'move'] },
          step: { type: 'integer' },
          title: { type: 'string' },
          kind: { type: 'string', enum: [...PLAN_STEP_KINDS] },
          after: { type: 'integer' },
          why: { type: 'string' },
        },
      },
    },
  },
} as const

export const PLAN_EDIT_RULE = 'planEdit: stel wijzigingen aan het plan voor als het plan zo het doel niet haalt: een stap die ontbreekt (op "add", title: een korte opdracht van hooguit 80 tekens, kind, after: het nummer van de stap waarna hij komt, of 0 voor het begin), een stap die niet meer nodig is omdat de kluis of dit gesprek laat zien dat het al klaar is of omdat hij niet bij het doel past (op "remove", step: het nummer), of een stap die eerder of later moet (op "move", step en after). why: in één korte zin waarom, op basis van wat je echt weet (het doel, de kluis, wat je opzocht); verzin geen eisen. Loop bij het nakijken elke stap die nog open is langs en leg hem naast de kluis die je ziet: laat de kluis al zien wat een stap moet opleveren (zoals een taalcertificaat voor een taalcursus, of een diploma voor een opleiding), stel dan voor die stap weg te halen en noem het item bij titel in why. Hooguit vier wijzigingen, alleen voor stappen die nog niet afgerond zijn, nooit een stap die er al staat (ook niet in andere woorden). Doe het als de gebruiker vraagt het plan na te kijken of aan te passen, als een stap net is afgerond en er daardoor iets verandert, of als je net iets nieuws weet (opgezocht, opleidingen gevonden, de kluis gezien) waar een stap uit volgt of waardoor een stap wegvalt. Zeg in text in één zin dat je een aanpassing van het plan voorstelt; de kaart eronder laat de wijzigingen zien, dus noem ze niet allemaal. Klopt het plan, zeg dat dan en laat planEdit null. Zei de gebruiker net nee of nog niet op een aanpassing van het plan, zeg dan kort dat het plan blijft zoals het is, zoek niets en stel niets nieuws voor; vraag alleen of de gebruiker verder wil met de stap van nu. Anders is planEdit null.'

export const NO_PLAN_EDIT_RULE = 'planEdit is altijd null.'

export interface PlanEditChange {
  op: 'add' | 'remove' | 'move'
  /** The step removed or moved. */
  stepId?: string
  /** For a new step its title; for one removed or moved, its title as it is now. */
  title: string
  kind?: string
  /** The step it comes after; null: at the start. Not for a removed step. */
  afterStepId?: string | null
  why: string
}

const MAX_PLAN_EDITS = 4

/** Only the changes that are real and do something; nothing when none is left. */
export function planEditProposal(raw: unknown, plan: PlanContext | undefined, id: string): AylaReply['planEdit'] {
  if (!plan || !raw || typeof raw !== 'object') return undefined
  const changes = (raw as { changes?: unknown }).changes
  if (!Array.isArray(changes)) return undefined
  const key = (text: string) => text.toLocaleLowerCase('nl').normalize('NFD').replace(/[^a-z0-9]/g, '')
  const titles = new Set(plan.steps.map((step) => key(step.title)))
  const touched = new Set<string>()
  const open = (number: unknown) => {
    if (typeof number !== 'number' || !Number.isInteger(number)) return undefined
    const step = plan.steps[number - 1]
    return step && step.status !== 'done' && !touched.has(step.id) ? step : undefined
  }
  const afterOf = (number: unknown, self?: string): string | null | undefined => {
    if (number === 0) return null
    if (typeof number !== 'number' || !Number.isInteger(number)) return undefined
    const step = plan.steps[number - 1]
    return step && step.id !== self ? step.id : undefined
  }
  const out: PlanEditChange[] = []
  for (const entry of changes as Record<string, unknown>[]) {
    const why = line(entry?.why, 160) ?? ''
    if (entry?.op === 'add') {
      const title = line(entry.title, 80)
      if (!title || titles.has(key(title))) continue
      const after = afterOf(entry.after)
      const kind = (PLAN_STEP_KINDS as readonly unknown[]).includes(entry.kind) ? entry.kind as string : 'general'
      titles.add(key(title))
      out.push({ op: 'add', title, kind, afterStepId: after === undefined ? plan.steps.at(-1)?.id ?? null : after, why })
    } else if (entry?.op === 'remove') {
      const step = open(entry.step)
      if (!step) continue
      touched.add(step.id)
      out.push({ op: 'remove', stepId: step.id, title: step.title, why })
    } else if (entry?.op === 'move') {
      const step = open(entry.step)
      if (!step) continue
      const after = afterOf(entry.after, step.id)
      const index = plan.steps.indexOf(step)
      const now = index === 0 ? null : plan.steps[index - 1].id
      if (after === undefined || after === now) continue
      touched.add(step.id)
      out.push({ op: 'move', stepId: step.id, title: step.title, afterStepId: after, why })
    }
    if (out.length === MAX_PLAN_EDITS) break
  }
  return out.length ? { id, planId: plan.id, changes: out } : undefined
}
