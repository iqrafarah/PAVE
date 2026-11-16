// Ayla's proposal to put something in the vault, for example "Zet mijn stage bij LiveWall in de kluis" on the Watch.
// It is only a proposal: the app saves it with the user's own session after the user says or taps Ja, and Ayla never
// says it has been saved.
import { type AylaReply, CATEGORIES, type Category, type VaultItemProposal } from './contract.ts'

/** How long the Ja/Nee stays valid. */
export const PROPOSAL_MINUTES = 60
const MAX_TITLE_LENGTH = 200
const MAX_FIELD_LENGTH = 200

export const CATEGORY_NAMES: Record<Category, string> = {
  diplomas: "Diploma's",
  certificates: 'Certificaten',
  badges: 'Badges',
  projects: 'Projecten',
  workExperience: 'Werkervaring',
  internships: 'Stages',
  skills: 'Vaardigheden',
  feedback: 'Feedback',
  reflections: 'Reflecties',
  other: 'Overige',
}

/** The part of the model's answer that describes the item; every field the user did not say is null. */
export const VAULT_ITEM_SCHEMA = {
  type: ['object', 'null'],
  additionalProperties: false,
  required: ['category', 'title', 'organisation', 'place', 'startDate', 'endDate', 'issuedOn', 'isCurrent'],
  properties: {
    category: { type: 'string', enum: [...CATEGORIES] },
    title: { type: 'string' },
    organisation: { type: ['string', 'null'] },
    place: { type: ['string', 'null'] },
    startDate: { type: ['string', 'null'] },
    endDate: { type: ['string', 'null'] },
    issuedOn: { type: ['string', 'null'] },
    isCurrent: { type: 'boolean' },
  },
} as const

/** A checked proposal, or undefined when the model gave nothing usable. */
export function vaultProposal(raw: unknown, id: string, now: Date): NonNullable<AylaReply['proposedAction']> | undefined {
  if (!raw || typeof raw !== 'object') return undefined
  const value = raw as Record<string, unknown>
  const category = value.category as Category
  if (!CATEGORIES.includes(category)) return undefined
  const title = text(value.title, MAX_TITLE_LENGTH)
  if (!title) return undefined

  const item: VaultItemProposal = { category, title }
  const organisationName = text(value.organisation, MAX_FIELD_LENGTH)
  const organisationLocation = text(value.place, MAX_FIELD_LENGTH)
  if (organisationName) item.organisationName = organisationName
  if (organisationLocation) item.organisationLocation = organisationLocation
  const startDate = day(value.startDate)
  const endDate = day(value.endDate)
  const issuedOn = day(value.issuedOn)
  if (startDate) item.startDate = startDate
  if (endDate && !(startDate && endDate < startDate)) item.endDate = endDate
  if (issuedOn) item.issuedOn = issuedOn
  if (value.isCurrent === true) {
    item.isCurrent = true
    delete item.endDate
  }

  return {
    id,
    kind: 'addVaultItem',
    summary: `${title} in je kluis zetten bij ${CATEGORY_NAMES[category]}`,
    expiresAt: new Date(now.getTime() + PROPOSAL_MINUTES * 60_000).toISOString(),
    vaultItem: item,
  }
}

function text(raw: unknown, max: number): string | undefined {
  if (typeof raw !== 'string') return undefined
  const value = raw.replace(/\s+/g, ' ').trim()
  return value ? value.slice(0, max) : undefined
}

/** A real calendar day as YYYY-MM-DD; a month alone ("2025-03") becomes its first day. */
function day(raw: unknown): string | undefined {
  if (typeof raw !== 'string') return undefined
  const match = raw.trim().match(/^(\d{4})-(\d{2})(?:-(\d{2}))?$/)
  if (!match) return undefined
  const [year, month, dayOfMonth] = [Number(match[1]), Number(match[2]), Number(match[3] ?? '1')]
  const date = new Date(Date.UTC(year, month - 1, dayOfMonth))
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== dayOfMonth) return undefined
  return `${match[1]}-${match[2]}-${String(dayOfMonth).padStart(2, '0')}`
}
