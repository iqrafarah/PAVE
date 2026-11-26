import type { Education } from './educations.ts'
// The Ayla contract, see shared/ayla/reply.schema.json.
import type { MemoryCategory } from './memory.ts'

export const CATEGORIES = ['diplomas', 'certificates', 'badges', 'projects', 'workExperience', 'internships', 'skills', 'feedback', 'reflections', 'other'] as const
/** At most this many pieces of evidence chosen for one conversation: a whole folder fits, as when sharing. */
export const MAX_CHOSEN_ITEMS = 100
export const SCREENS = ['home', 'chat', 'vault', 'vaultItem', 'addEvidence', 'plans', 'vacancies', 'profile', 'settings'] as const
export const DEVICES = ['watch', 'phone', 'web'] as const

export type Category = (typeof CATEGORIES)[number]
export type Screen = (typeof SCREENS)[number]
export type Device = (typeof DEVICES)[number]

/** A file the user added to the message. The app reads the text on the device; the file itself is not sent. */
/** A file the user added: its text, and for a photo a small JPEG (base64) so Ayla can look at it. Neither is stored. */
export interface Attachment { name: string; text: string; image?: string }

export interface AylaRequest {
  conversationId?: string
  /** Starts a new conversation inside this project. Ignored when conversationId is given. */
  projectId?: string
  /** Starts a new conversation inside this plan, for this step of it. Ignored when conversationId is given. */
  planId?: string
  planStepId?: string
  text: string
  device: Device
  input: 'voice' | 'text'
  context?: Context
  attachments?: Attachment[]
  /** How the app is set right now, so Ayla can say how something stands and does not do what is already so. */
  app?: AppState
  /**
   * What came of the actions of Ayla's previous answer, sent by the app itself and not typed by the user: she then
   * goes on with what was asked. Such a turn stores no user message.
   */
  results?: ActionResult[]
  /** The language the app is in (Instellingen › Taal): Ayla answers in it. Missing means Dutch. */
  language?: Language
}

export const LANGUAGES = ['nl', 'en', 'pap'] as const
export type Language = (typeof LANGUAGES)[number]

export interface ActionResult { do: ActionKind; ok: boolean; said?: string }

/** Settings and the open conversation as the app has them. No vault content and no names of folders or evidence. */
export interface AppState {
  theme?: string
  textSize?: string
  displayMode?: string
  vaultLayout?: string
  voiceText?: boolean
  animations?: boolean
  memory?: boolean
  chatTitle?: string
  chatPinned?: boolean
  /** What is on screen right now, in a few words the app writes itself ("de lijst met vacatures, tabblad Bewaard"). */
  seeing?: string
  font?: string
  /** The user's plans, one line each as the app writes it: name, how far, and the step they are on. At most 8. */
  plans?: string[]
  /** The names of the user's projects in Ayla. At most 12. */
  projects?: string[]
  /** Invitations from employers at the fair, one line each as the app writes it: who, for what, when, answered or not. At most 6. */
  invitations?: string[]
}

/** The vacancy the user has open in the app, as the card shows it, so "past deze bij mij?" is about that one. */
export interface VacancyContext {
  title: string
  company: string
  city?: string
  summary?: string
  matches: string[]
  skillGap: string[]
}

/**
 * What the user asked for with a button on a vacancy card, or the mode of the spoken conversation: compare the vacancies
 * in `compare`, or what is missing, help to apply, or practise an interview for the open `vacancy`.
 */
export const VACANCY_TASKS = ['compare', 'gaps', 'prepare', 'interview'] as const
export type VacancyTask = (typeof VACANCY_TASKS)[number]

export interface Context {
  screen: Screen
  itemId?: string
  itemIds?: string[]
  vacancy?: VacancyContext
  /** Two or three vacancies the user picked to compare. */
  compare?: VacancyContext[]
  task?: VacancyTask
}

export interface Choice { id: string; label: string }

/**
 * What Ayla can do in the app herself, when the user asks for it. The app carries an action out and says so when it
 * cannot (a folder that does not exist). Names of folders, evidence and chats are the user's own words: the app looks
 * them up, the model never gets a list of them.
 */
export const ACTIONS = [
  'openSettingsPage', 'openMemory', 'openSavedVacancies', 'openFolder', 'back', 'close',
  'newChat', 'openChat', 'renameChat', 'pinChat', 'archiveChat', 'setChatExpiry',
  'setTheme', 'setTextSize', 'setDisplayMode', 'setVaultLayout', 'setVoiceText', 'setChatsInSearch', 'setAnimations', 'setMemory',
  'createFolder', 'moveToFolder', 'archiveEvidence', 'allowAyla', 'requestVerification',
  'openVacancy', 'saveVacancy',
  'openNotifications', 'openApplications', 'openApplication', 'openProject', 'setFontStyle',
  'openPlan', 'addPlanStep', 'markPlanStep', 'renamePlanStep', 'describePlanStep', 'linkPlanToProject', 'makeVacancyPlan',
  'addTalkToCalendar', 'openMail', 'summarizeMail', 'replyMail',
  'shareWith', 'stopSharing', 'showShares',
  'deleteChat', 'deleteEvidence', 'signOut', 'forgetAll', 'removePlanStep', 'answerInvitation', 'addProjectSource',
] as const
export type ActionKind = (typeof ACTIONS)[number]

/** What cannot be undone: PAVE asks Ja or Nee first, and the app only acts after Ja. */
export const CONFIRMED_ACTIONS: readonly ActionKind[] = ['deleteChat', 'deleteEvidence', 'signOut', 'forgetAll', 'removePlanStep', 'answerInvitation', 'addProjectSource']

export interface AppAction { do: ActionKind; value?: string; target?: string; confirm?: true }

/** Also asks first: Ayla giving herself the use of a piece of evidence. Taking it away needs no question. */
export function needsConfirmation(kind: ActionKind, value: string): boolean {
  return CONFIRMED_ACTIONS.includes(kind) || (kind === 'allowAyla' && /^(on|aan|true|ja)$/i.test(value))
}

/** What Ayla is doing while she has nothing to say yet, so the app can show it. */
export type Status =
  | { kind: 'vacancySearch'; what: string; where: string; also?: string }
  /** chosen: how many vault items the user picked for this conversation, when that is what Ayla compares with. */
  | { kind: 'vacancyMatch'; count: number; withVault: boolean; chosen?: number }
  | { kind: 'educationSearch'; what: string; where: string }

export interface RequirementLink { skill: string; requirement: string }

export interface Vacancy {
  id: string
  title: string
  company: string
  city?: string
  employment?: 'fullTime' | 'partTime'
  salary?: { min: number; max: number; period: 'month' | 'year'; currency: 'EUR'; isEstimate: boolean }
  logoUrl?: string
  url?: string
  source: 'example' | 'adzuna' | 'jooble' | 'web'
  /** A short piece of the vacancy text, as the source gives it. Never the whole text. */
  summary?: string
  /** The day the source last saw it (YYYY-MM-DD), when it says so. */
  postedAt?: string
  matches: RequirementLink[]
  skillGap: RequirementLink[]
}

export type Block =
  | { type: 'vaultSelection'; categories: { category: Category; count: number }[] }
  /** search: what Ayla searched for, so the apps can show it and a later turn can search the same again. */
  | { type: 'vacancies'; items: Vacancy[]; search?: { what: string; where: string; also?: string } }
  | { type: 'skillSuggestions'; itemId: string; skills: { name: string; reason: string }[] }
  /** Studies and courses found on the web, each with its own page. */
  | { type: 'educations'; items: Education[]; search: { what: string; where: string } }
  | { type: 'cv'; profile: string; experience: { title: string; organisation: string; period: string; description?: string }[]; skills: string[] }

/** An item Ayla proposes for the vault, in the fields of `vault_items`; dates as YYYY-MM-DD. */
export interface VaultItemProposal {
  category: Category
  title: string
  organisationName?: string
  organisationLocation?: string
  startDate?: string
  endDate?: string
  issuedOn?: string
  isCurrent?: boolean
  /** What the user did or achieved, in a sentence or two, as far as they told it. */
  description?: string
  /** At most five skills that show in it. */
  skills?: string[]
  /** The names of the files sent in the conversation that belong to this item. */
  attachments?: string[]
}

export interface AylaReply {
  version: 1
  id: string
  conversationId: string
  text: string
  question?: { text: string; choices: Choice[] }
  accessRequest?: { id: string; purpose: string; categories: Category[] }
  proposedAction?: {
    id: string
    kind: 'addVaultItem' | 'updatePlan' | 'createPlan' | 'draftProfile' | 'requestValidation'
    summary: string
    expiresAt: string
    /** With `addVaultItem`: what to put in the vault once the user confirms. */
    vaultItem?: VaultItemProposal
    /** With `updatePlan`: the step of the conversation's plan Ayla changed. It is saved already; the apps show it. */
    planStep?: { planId: string; stepId: string; status: 'upcoming' | 'active' | 'done' | 'skipped' }
    /** With `createPlan`: the plan the user asked for. The app saves it with the user's own session and puts the chat in it. */
    newPlan?: { name: string; goal: string; steps: { title: string; summary: string; kind: string }[] }
  }
  blocks: Block[]
  navigation?: { screen: Screen; itemId?: string }
  /** What Ayla does in the app with this answer, in order. With `confirm`, only after the user says Ja. */
  actions?: AppAction[]
  /** She is not done yet: the app tells her what came of these actions (`results`) and she goes on. */
  continues?: true
  /**
   * Ayla suggests remembering these facts, one per item, and taking away notes they make out of date (`replaces`,
   * the exact text of the user's note; with an empty `text` only that). Nothing changes before the user confirms.
   */
  memories?: { text: string; category: MemoryCategory; replaces?: string }[]
  /** The notes about the user this answer leans on, so the apps can show "Gebaseerd op". */
  usedMemories?: { text: string; category: MemoryCategory }[]
  usedData: Category[]
}

export const MAX_TEXT_LENGTH = 4000
export const MAX_ATTACHMENTS = 5
export const MAX_ATTACHMENT_LENGTH = 20000
export const MAX_ATTACHMENT_NAME_LENGTH = 200
/** About 1 MB of JPEG: the app sends photos of at most 1024 points. */
export const MAX_ATTACHMENT_IMAGE_BASE64 = 1_400_000
export const MAX_ATTACHMENT_IMAGES = 4
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Returns the request, or a reason why it is not valid. */
export function parseRequest(body: unknown): AylaRequest | string {
  if (typeof body !== 'object' || body === null) return 'body must be an object'
  const b = body as Record<string, unknown>
  const allowed = new Set(['conversationId', 'projectId', 'planId', 'planStepId', 'text', 'device', 'input', 'context', 'attachments', 'app', 'results', 'language'])
  const extra = Object.keys(b).find((key) => !allowed.has(key))
  if (extra) return `unknown field ${extra}`
  if (typeof b.text !== 'string' || !b.text.trim()) return 'text is required'
  if (b.text.length > MAX_TEXT_LENGTH) return 'text is too long'
  if (!DEVICES.includes(b.device as Device)) return 'device is not valid'
  if (b.input !== 'voice' && b.input !== 'text') return 'input is not valid'
  if (b.language !== undefined && !LANGUAGES.includes(b.language as Language)) return 'language is not valid'
  if (b.conversationId !== undefined && (typeof b.conversationId !== 'string' || !UUID.test(b.conversationId))) {
    return 'conversationId is not valid'
  }
  if (b.projectId !== undefined && (typeof b.projectId !== 'string' || !UUID.test(b.projectId))) {
    return 'projectId is not valid'
  }
  if (b.planId !== undefined && (typeof b.planId !== 'string' || !UUID.test(b.planId))) return 'planId is not valid'
  if (b.planStepId !== undefined && (typeof b.planStepId !== 'string' || !UUID.test(b.planStepId) || !b.planId)) {
    return 'planStepId is not valid'
  }
  let context: AylaRequest['context']
  if (b.context !== undefined) {
    const c = b.context as Record<string, unknown>
    if (typeof c !== 'object' || c === null || !SCREENS.includes(c.screen as Screen)) return 'context is not valid'
    if (c.itemId !== undefined && typeof c.itemId !== 'string') return 'context is not valid'
    // Several items chosen with the plus button, for the whole conversation.
    if (c.itemIds !== undefined && (!Array.isArray(c.itemIds) || c.itemIds.length > MAX_CHOSEN_ITEMS || !c.itemIds.every((id) => typeof id === 'string' && id.trim()))) return 'context is not valid'
    const itemIds = Array.isArray(c.itemIds) && c.itemIds.length ? (c.itemIds as string[]) : undefined
    // Also with items chosen from the vault: the vacancy is open while those items are what Ayla may use.
    const showsVacancies = c.screen === 'vacancies' || c.screen === 'vault' || c.screen === 'vaultItem'
    let vacancy: VacancyContext | undefined
    if (c.vacancy !== undefined) {
      if (!showsVacancies) return 'context is not valid'
      const parsed = parseVacancyContext(c.vacancy)
      if (!parsed) return 'context is not valid'
      vacancy = parsed
    }
    let compare: VacancyContext[] | undefined
    if (c.compare !== undefined) {
      if (!showsVacancies || !Array.isArray(c.compare) || c.compare.length < 2 || c.compare.length > 3) return 'context is not valid'
      const parsed = c.compare.map(parseVacancyContext)
      if (parsed.some((entry) => !entry)) return 'context is not valid'
      compare = parsed as VacancyContext[]
    }
    let task: VacancyTask | undefined
    if (c.task !== undefined) {
      if (!VACANCY_TASKS.includes(c.task as VacancyTask)) return 'context is not valid'
      task = c.task as VacancyTask
      if (task === 'compare' ? !compare : !vacancy) return 'context is not valid'
    }
    context = {
      screen: c.screen as Screen,
      ...(c.itemId ? { itemId: c.itemId as string } : {}),
      ...(itemIds ? { itemIds } : {}),
      ...(vacancy ? { vacancy } : {}),
      ...(compare ? { compare } : {}),
      ...(task ? { task } : {}),
    }
  }
  let attachments: Attachment[] | undefined
  if (b.attachments !== undefined) {
    if (!Array.isArray(b.attachments) || b.attachments.length > MAX_ATTACHMENTS) return 'attachments are not valid'
    attachments = []
    for (const item of b.attachments) {
      const a = item as Record<string, unknown>
      if (typeof a !== 'object' || a === null) return 'attachments are not valid'
      if (typeof a.name !== 'string' || !a.name.trim() || a.name.length > MAX_ATTACHMENT_NAME_LENGTH) return 'attachments are not valid'
      if (typeof a.text !== 'string' || !a.text.trim() || a.text.length > MAX_ATTACHMENT_LENGTH) return 'attachments are not valid'
      const attachment: Attachment = { name: a.name.trim(), text: a.text.trim() }
      if (a.image !== undefined) {
        if (typeof a.image !== 'string' || a.image.length > MAX_ATTACHMENT_IMAGE_BASE64 || !/^[A-Za-z0-9+/]+=*$/.test(a.image)) return 'attachments are not valid'
        if (attachments.filter((f) => f.image).length >= MAX_ATTACHMENT_IMAGES) return 'attachments are not valid'
        attachment.image = a.image
      }
      attachments.push(attachment)
    }
  }
  let app: AppState | undefined
  if (b.app !== undefined) {
    const parsed = parseAppState(b.app)
    if (!parsed) return 'app is not valid'
    app = parsed
  }
  let results: ActionResult[] | undefined
  if (b.results !== undefined) {
    // Only for a conversation that exists: there is an answer of Ayla's these belong to.
    if (!Array.isArray(b.results) || !b.results.length || b.results.length > 8 || !b.conversationId) return 'results are not valid'
    results = []
    for (const entry of b.results as Record<string, unknown>[]) {
      if (typeof entry !== 'object' || entry === null || !ACTIONS.includes(entry.do as ActionKind) || typeof entry.ok !== 'boolean') return 'results are not valid'
      if (entry.said !== undefined && (typeof entry.said !== 'string' || entry.said.length > 300)) return 'results are not valid'
      const said = typeof entry.said === 'string' ? entry.said.replace(/\s+/g, ' ').trim() : ''
      results.push({ do: entry.do as ActionKind, ok: entry.ok, ...(said ? { said } : {}) })
    }
  }
  return {
    text: b.text.trim(),
    device: b.device as Device,
    input: b.input,
    ...(b.language && b.language !== 'nl' ? { language: b.language as Language } : {}),
    ...(app ? { app } : {}),
    ...(results ? { results } : {}),
    ...(b.conversationId ? { conversationId: b.conversationId as string } : {}),
    ...(b.projectId && !b.conversationId ? { projectId: b.projectId as string } : {}),
    ...(b.planId && !b.conversationId ? { planId: b.planId as string } : {}),
    ...(b.planStepId && b.planId && !b.conversationId ? { planStepId: b.planStepId as string } : {}),
    ...(context ? { context } : {}),
    ...(attachments?.length ? { attachments } : {}),
  }
}

const APP_WORDS = ['theme', 'textSize', 'displayMode', 'vaultLayout', 'chatTitle', 'seeing', 'font'] as const
const APP_LISTS = { plans: { count: 8, length: 200 }, projects: { count: 12, length: 80 }, invitations: { count: 6, length: 200 } } as const
const APP_SWITCHES = ['voiceText', 'animations', 'memory', 'chatPinned'] as const

function parseAppState(raw: unknown): AppState | null {
  const a = raw as Record<string, unknown>
  if (typeof a !== 'object' || a === null || Array.isArray(a)) return null
  const known = new Set<string>([...APP_WORDS, ...APP_SWITCHES, ...Object.keys(APP_LISTS)])
  if (Object.keys(a).some((key) => !known.has(key))) return null
  const state: AppState = {}
  for (const key of APP_WORDS) {
    if (a[key] === undefined) continue
    if (typeof a[key] !== 'string' || (a[key] as string).length > (key === 'seeing' ? 200 : 80)) return null
    const word = (a[key] as string).replace(/\s+/g, ' ').trim()
    if (word) state[key] = word
  }
  for (const key of APP_SWITCHES) {
    if (a[key] === undefined) continue
    if (typeof a[key] !== 'boolean') return null
    state[key] = a[key] as boolean
  }
  for (const [key, limit] of Object.entries(APP_LISTS) as [keyof typeof APP_LISTS, { count: number; length: number }][]) {
    if (a[key] === undefined) continue
    const list = a[key]
    if (!Array.isArray(list) || list.length > limit.count || list.some((line) => typeof line !== 'string' || line.length > limit.length)) return null
    const lines = (list as string[]).map((line) => line.replace(/\s+/g, ' ').trim()).filter(Boolean)
    if (lines.length) state[key] = lines
  }
  return state
}

function parseVacancyContext(raw: unknown): VacancyContext | null {
  const v = raw as Record<string, unknown>
  if (typeof v !== 'object' || v === null) return null
  const text = (value: unknown, max: number) => typeof value === 'string' && value.trim().length > 0 && value.length <= max
  const list = (value: unknown) => Array.isArray(value) && value.length <= 8 && value.every((skill) => text(skill, 120))
  if (!text(v.title, 200) || !text(v.company, 200) || !list(v.matches) || !list(v.skillGap)) return null
  if (v.city !== undefined && !text(v.city, 200)) return null
  if (v.summary !== undefined && !text(v.summary, 600)) return null
  return {
    title: (v.title as string).trim(),
    company: (v.company as string).trim(),
    ...(v.city ? { city: (v.city as string).trim() } : {}),
    ...(v.summary ? { summary: (v.summary as string).trim() } : {}),
    matches: (v.matches as string[]).map((skill) => skill.trim()),
    skillGap: (v.skillGap as string[]).map((skill) => skill.trim()),
  }
}
