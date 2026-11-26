import { assertEquals } from 'jsr:@std/assert@1'
import { type ApplicationRow, inboxView, parseInboxRequest, photoPath, profileCode, sameHash, sha256 } from '../inbox.ts'

const now = new Date('2026-11-25T12:00:00Z')
const key = 'abcdefghijklmnop1234'

Deno.test('a request needs a slug, a key and a known action', () => {
  assertEquals(parseInboxRequest({ slug: 'jumbo', key, action: 'list' }, now), { slug: 'jumbo', key, action: 'list' })
  assertEquals(parseInboxRequest({ slug: 'Jumbo!', key, action: 'list' }, now), { error: 'invalid_request' })
  assertEquals(parseInboxRequest({ slug: 'jumbo', key: 'short', action: 'list' }, now), { error: 'invalid_request' })
  assertEquals(parseInboxRequest({ slug: 'jumbo', key, action: 'delete' }, now), { error: 'invalid_request' })
})

Deno.test('an invitation is for a moment in the next two months', () => {
  const id = '11111111-1111-1111-1111-111111111111'
  const ok = parseInboxRequest({ slug: 'jumbo', key, action: 'invite', applicationID: id, moment: '2026-11-28T10:00:00Z', message: '  Tot zaterdag!  ' }, now)
  assertEquals(ok, { slug: 'jumbo', key, action: 'invite', applicationID: id, moment: '2026-11-28T10:00:00.000Z', message: 'Tot zaterdag!' })
  assertEquals(parseInboxRequest({ slug: 'jumbo', key, action: 'invite', applicationID: id, moment: '2026-11-24T10:00:00Z' }, now), { error: 'invalid_moment' })
  assertEquals(parseInboxRequest({ slug: 'jumbo', key, action: 'invite', applicationID: id, moment: '2027-03-01T10:00:00Z' }, now), { error: 'invalid_moment' })
  assertEquals(parseInboxRequest({ slug: 'jumbo', key, action: 'invite', applicationID: 'x', moment: '2026-11-28T10:00:00Z' }, now), { error: 'invalid_request' })
})

Deno.test('keys are compared by hash', async () => {
  const hash = await sha256(key)
  assertEquals(hash.length, 64)
  assertEquals(sameHash(await sha256(key), hash), true)
  assertEquals(sameHash(await sha256(key + 'x'), hash), false)
})

Deno.test('the employer sees only the card', () => {
  const view = inboxView({
    id: 'a', employer_slug: 'jumbo', vacancy_id: 'v', vacancy_title: 'Bijbaan', status: 'new', invited_for: null, invitation_message: null, answer: null,
    created_at: '2026-11-25T12:00:00Z',
    card: { name: 'Sam', why: 'Ik werk graag met mensen.', availability: { days: ['zaterdag', 3], maxHours: 12 }, email: 'nooit@voorbeeld.nl' },
  })
  assertEquals(view.name, 'Sam')
  assertEquals(view.availability, { days: ['zaterdag'], maxHours: 12 })
  assertEquals('email' in view, false)
})

Deno.test('the photo and the shared profile go along only when the applicant chose them', () => {
  const owner = '11111111-1111-1111-1111-111111111111'
  const row: ApplicationRow = {
    id: 'a', user_id: owner, employer_slug: 'jumbo', vacancy_id: 'v', vacancy_title: 'Bijbaan',
    card: { name: 'Ravi', showsPhoto: true, profileCode: 'a'.repeat(32) }, status: 'new', invited_for: null,
    invitation_message: null, answer: null, created_at: '2026-11-26T09:00:00Z',
  }
  assertEquals(photoPath(row, `${owner}/foto.jpg`), `${owner}/foto.jpg`)
  assertEquals(photoPath(row, 'someone-else/foto.jpg'), undefined)
  assertEquals(photoPath(row, `${owner}/../x.jpg`), undefined)
  assertEquals(photoPath({ ...row, card: { name: 'Ravi' } }, `${owner}/foto.jpg`), undefined)
  assertEquals(profileCode(row), 'a'.repeat(32))
  assertEquals(profileCode({ ...row, card: { profileCode: '../gedeeld' } }), undefined)
  const view = inboxView(row, 'https://signed')
  assertEquals(view.photo, 'https://signed')
  assertEquals(view.profileCode, 'a'.repeat(32))
  assertEquals(inboxView({ ...row, card: { name: 'Ravi' } }).photo, undefined)
})
