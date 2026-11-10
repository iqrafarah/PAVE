// The Ayla contract, see shared/ayla/reply.schema.json.

export const CATEGORIES = ['diplomas', 'certificates', 'badges', 'projects', 'workExperience', 'internships', 'skills', 'feedback', 'reflections'] as const
export const SCREENS = ['home', 'chat', 'vault', 'vaultItem', 'addEvidence', 'plans', 'vacancies', 'profile', 'settings'] as const
export const DEVICES = ['watch', 'phone', 'web'] as const

export type Category = (typeof CATEGORIES)[number]
export type Screen = (typeof SCREENS)[number]
export type Device = (typeof DEVICES)[number]

/** A file the user added to the message. The app reads the text on the device; the file itself is not sent. */
export interface Attachment { name: string; text: string }

export interface AylaRequest {
  conversationId?: string
  text: string
  device: Device
  input: 'voice' | 'text'
  context?: { screen: Screen; itemId?: string }
  attachments?: Attachment[]
}

export interface Choice { id: string; label: string }

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
  source: 'example' | 'adzuna'
  matches: RequirementLink[]
  skillGap: RequirementLink[]
}

export type Block =
  | { type: 'vaultSelection'; categories: { category: Category; count: number }[] }
  | { type: 'vacancies'; items: Vacancy[] }
  | { type: 'skillSuggestions'; itemId: string; skills: { name: string; reason: string }[] }
  | { type: 'cv'; profile: string; experience: { title: string; organisation: string; period: string; description?: string }[]; skills: string[] }

export interface AylaReply {
  version: 1
  id: string
  conversationId: string
  text: string
  question?: { text: string; choices: Choice[] }
  accessRequest?: { id: string; purpose: string; categories: Category[] }
  proposedAction?: { id: string; kind: 'addVaultItem' | 'updatePlan' | 'draftProfile' | 'requestValidation'; summary: string; expiresAt: string }
  blocks: Block[]
  navigation?: { screen: Screen; itemId?: string }
  usedData: Category[]
}

export const MAX_TEXT_LENGTH = 4000
export const MAX_ATTACHMENTS = 3
export const MAX_ATTACHMENT_LENGTH = 20000
export const MAX_ATTACHMENT_NAME_LENGTH = 200
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Returns the request, or a reason why it is not valid. */
export function parseRequest(body: unknown): AylaRequest | string {
  if (typeof body !== 'object' || body === null) return 'body must be an object'
  const b = body as Record<string, unknown>
  const allowed = new Set(['conversationId', 'text', 'device', 'input', 'context', 'attachments'])
  const extra = Object.keys(b).find((key) => !allowed.has(key))
  if (extra) return `unknown field ${extra}`
  if (typeof b.text !== 'string' || !b.text.trim()) return 'text is required'
  if (b.text.length > MAX_TEXT_LENGTH) return 'text is too long'
  if (!DEVICES.includes(b.device as Device)) return 'device is not valid'
  if (b.input !== 'voice' && b.input !== 'text') return 'input is not valid'
  if (b.conversationId !== undefined && (typeof b.conversationId !== 'string' || !UUID.test(b.conversationId))) {
    return 'conversationId is not valid'
  }
  let context: AylaRequest['context']
  if (b.context !== undefined) {
    const c = b.context as Record<string, unknown>
    if (typeof c !== 'object' || c === null || !SCREENS.includes(c.screen as Screen)) return 'context is not valid'
    if (c.itemId !== undefined && typeof c.itemId !== 'string') return 'context is not valid'
    context = { screen: c.screen as Screen, ...(c.itemId ? { itemId: c.itemId as string } : {}) }
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
      attachments.push({ name: a.name.trim(), text: a.text.trim() })
    }
  }
  return {
    text: b.text.trim(),
    device: b.device as Device,
    input: b.input,
    ...(b.conversationId ? { conversationId: b.conversationId as string } : {}),
    ...(context ? { context } : {}),
    ...(attachments?.length ? { attachments } : {}),
  }
}
