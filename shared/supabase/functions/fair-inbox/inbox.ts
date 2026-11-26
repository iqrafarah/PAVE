// The employer's side of the fair demo: with the employer's secret key, see who applied for its vacancies and invite
// someone for a talk. The key only travels in the request body, and only its hash is kept.

export type Action = 'list' | 'invite'

export interface InboxRequest {
  slug: string
  key: string
  action: Action
  applicationID?: string
  moment?: string
  message?: string
}

export interface ApplicationRow {
  id: string
  employer_slug: string
  vacancy_id: string
  vacancy_title: string
  card: Record<string, unknown>
  status: 'new' | 'invited' | 'declined'
  invited_for: string | null
  invitation_message: string | null
  answer: 'accepted' | 'declined' | null
  created_at: string
}

const SLUG = /^[a-z0-9-]{2,40}$/
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** The request, checked; or what is wrong with it. */
export function parseInboxRequest(body: unknown, now: Date): InboxRequest | { error: string } {
  const b = body as Record<string, unknown> | null
  if (!b || typeof b.slug !== 'string' || !SLUG.test(b.slug)) return { error: 'invalid_request' }
  if (typeof b.key !== 'string' || b.key.length < 16 || b.key.length > 128) return { error: 'invalid_request' }
  if (b.action !== 'list' && b.action !== 'invite') return { error: 'invalid_request' }
  if (b.action === 'list') return { slug: b.slug, key: b.key, action: 'list' }
  if (typeof b.applicationID !== 'string' || !UUID.test(b.applicationID)) return { error: 'invalid_request' }
  const moment = typeof b.moment === 'string' ? new Date(b.moment) : undefined
  // A talk in the future, within two months.
  if (!moment || isNaN(moment.getTime()) || moment.getTime() <= now.getTime() || moment.getTime() > now.getTime() + 61 * 86_400_000) {
    return { error: 'invalid_moment' }
  }
  const message = typeof b.message === 'string' ? b.message.trim().slice(0, 400) : undefined
  return { slug: b.slug, key: b.key, action: 'invite', applicationID: b.applicationID, moment: moment.toISOString(), message: message || undefined }
}

export async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

/** Compares in constant time, so the key cannot be guessed from how long a wrong one takes. */
export function sameHash(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let difference = 0
  for (let index = 0; index < a.length; index++) difference |= a.charCodeAt(index) ^ b.charCodeAt(index)
  return difference === 0
}

/** What the employer sees of one application: the card the applicant left, never their account. */
export function inboxView(row: ApplicationRow) {
  const card = row.card ?? {}
  const text = (value: unknown, max: number) => typeof value === 'string' ? value.slice(0, max) : undefined
  const availability = (card.availability ?? {}) as Record<string, unknown>
  return {
    id: row.id,
    vacancyID: row.vacancy_id,
    vacancyTitle: row.vacancy_title,
    name: text(card.name, 80),
    headline: text(card.headline, 120),
    why: text(card.why, 600),
    pitch: text(card.pitch, 1200),
    availability: {
      days: Array.isArray(availability.days) ? availability.days.filter((day) => typeof day === 'string').slice(0, 7) : [],
      maxHours: typeof availability.maxHours === 'number' ? availability.maxHours : undefined,
    },
    status: row.status,
    invitedFor: row.invited_for ?? undefined,
    answer: row.answer ?? undefined,
    appliedAt: row.created_at,
  }
}
