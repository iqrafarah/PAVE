// What someone sees through a shared link: only what the owner chose, only while the share is on. Pure functions, so
// the rules can be tested without a database; index.ts reads and writes.

export type ShareState = 'active' | 'paused' | 'revoked' | 'expired'
export type ViewAction = 'view' | 'download'

export interface ShareRow {
  id: string
  user_id: string
  title: string
  recipient_name: string
  recipient_organisation: string | null
  purpose: string | null
  template: string
  item_ids: string[]
  content: Record<string, unknown>
  allows_download: boolean
  expires_at: string
  paused_at: string | null
  revoked_at: string | null
}

export interface ItemRow {
  id: string
  user_id: string
  category: string
  title: string
  description: string | null
  organisation_name: string | null
  organisation_location: string | null
  start_date: string | null
  end_date: string | null
  issued_on: string | null
  is_current: boolean | null
  verification_status: string | null
  source: string | null
  archived_at: string | null
  vault_item_skills?: { name: string; status: string | null }[] | null
}

export interface ViewRequest {
  code: string
  action: ViewAction
  viewer?: { name?: string; organisation?: string }
}

const text = (value: unknown, max: number) => (typeof value === 'string' ? value.replace(/\s+/g, ' ').trim().slice(0, max) : '')

/** The checked request, or what is wrong with it. */
export function parseViewRequest(body: unknown): ViewRequest | string {
  if (!body || typeof body !== 'object') return 'body'
  const b = body as Record<string, unknown>
  const code = typeof b.code === 'string' ? b.code.trim().toLowerCase() : ''
  if (!/^[0-9a-f]{32}$/.test(code)) return 'code'
  const action: ViewAction = b.action === 'download' ? 'download' : 'view'
  const v = (b.viewer ?? {}) as Record<string, unknown>
  const name = text(v.name, 80)
  const organisation = text(v.organisation, 80)
  return { code, action, viewer: name || organisation ? { name: name || undefined, organisation: organisation || undefined } : undefined }
}

export function shareState(share: Pick<ShareRow, 'expires_at' | 'paused_at' | 'revoked_at'>, now: Date): ShareState {
  if (share.revoked_at) return 'revoked'
  if (new Date(share.expires_at).getTime() <= now.getTime()) return 'expired'
  if (share.paused_at) return 'paused'
  return 'active'
}

/** A piece of evidence as the recipient sees it: its status from the vault now, never from the share. */
export function itemView(item: ItemRow) {
  return {
    id: item.id,
    category: item.category,
    title: item.title,
    description: item.description ?? undefined,
    organisation: [item.organisation_name, item.organisation_location].filter(Boolean).join(', ') || undefined,
    startDate: item.start_date ?? undefined,
    endDate: item.end_date ?? undefined,
    issuedOn: item.issued_on ?? undefined,
    isCurrent: item.is_current ?? false,
    verified: item.verification_status === 'verified',
    skills: (item.vault_item_skills ?? []).filter((s) => s.status !== 'rejected').map((s) => s.name).slice(0, 20),
  }
}

/**
 * Only the evidence the share names, of its owner, not archived and not rejected; in the order the owner chose. What the
 * owner shared briefly ("kort", listed in `content.brief`) shows without its description and skills.
 */
export function chosenItems(share: ShareRow, items: ItemRow[]) {
  const byId = new Map(items.map((item) => [item.id, item]))
  const brief = new Set(Array.isArray(share.content.brief) ? (share.content.brief as unknown[]).filter((id) => typeof id === 'string') : [])
  return share.item_ids
    .map((id) => byId.get(id))
    .filter((item): item is ItemRow => !!item && item.user_id === share.user_id && !item.archived_at && item.verification_status !== 'rejected')
    .map(itemView)
    .map((view) => brief.has(view.id) ? { ...view, description: undefined, skills: [] } : view)
}

/** The kept files of a share, only under its own folder. */
export function documentPaths(share: ShareRow): { kind: 'cv' | 'letter'; path: string }[] {
  const documents = (share.content.documents ?? {}) as Record<string, unknown>
  const prefix = `${share.user_id}/${share.id}/`
  return (['cv', 'letter'] as const)
    .map((kind) => ({ kind, path: typeof documents[kind] === 'string' ? (documents[kind] as string) : '' }))
    .filter((doc) => doc.path.startsWith(prefix) && !doc.path.includes('..') && doc.path.endsWith('.pdf'))
}

/** What the page receives for an active share. */
export function shareView(share: ShareRow, items: ItemRow[], documents: { kind: string; url: string }[]) {
  const content = share.content
  const profile = (content.profile ?? {}) as Record<string, unknown>
  return {
    state: 'active' as ShareState,
    title: share.title,
    purpose: share.purpose ?? undefined,
    recipient: { name: share.recipient_name, organisation: share.recipient_organisation ?? undefined },
    expiresAt: share.expires_at,
    allowsDownload: share.allows_download,
    profile: {
      name: text(profile.name, 120),
      headline: text(profile.headline, 120) || undefined,
      email: text(profile.email, 200) || undefined,
      phone: text(profile.phone, 40) || undefined,
      city: text(profile.city, 80) || undefined,
      summary: text(profile.summary, 1200) || undefined,
    },
    items: chosenItems(share, items),
    cv: typeof content.cv === 'object' && content.cv ? content.cv : undefined,
    letter: typeof content.letter === 'object' && content.letter ? content.letter : undefined,
    documents,
  }
}
