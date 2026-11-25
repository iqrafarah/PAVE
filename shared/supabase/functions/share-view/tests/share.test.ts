import { assertEquals } from 'jsr:@std/assert@1'
import { chosenItems, documentPaths, fileItemIDs, parseViewRequest, sharedFiles, shareState, shareView, verifications, type FileRow, type ItemRow, type ShareRow, type VerificationRow } from '../share.ts'

const owner = '11111111-1111-1111-1111-111111111111'
const share: ShareRow = {
  id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  user_id: owner,
  title: 'Sollicitatie Junior IT-consultant',
  recipient_name: 'Sanne de Vries',
  recipient_organisation: 'Kade Consultancy',
  purpose: 'Sollicitatie',
  template: 'employer',
  item_ids: ['i2', 'i1', 'gone', 'other', 'archived', 'rejected'],
  content: {
    profile: { name: 'Ravi Santoso', headline: 'Student HBO-ICT', email: 'ravi@voorbeeld.nl', secret: 'nooit' },
    documents: { cv: `${owner}/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/cv.pdf`, letter: `${owner}/other-share/letter.pdf` },
  },
  allows_download: false,
  expires_at: '2026-12-09T12:00:00Z',
  paused_at: null,
  revoked_at: null,
}

function item(id: string, extra: Partial<ItemRow> = {}): ItemRow {
  return {
    id, user_id: owner, category: 'internships', title: `Titel ${id}`, description: null, organisation_name: 'Pixelwerk',
    organisation_location: 'Eindhoven', start_date: '2026-02-01', end_date: null, issued_on: null, is_current: true,
    verification_status: 'toVerify', source: 'user', archived_at: null, vault_item_skills: [{ name: 'Swift', status: null }, { name: 'Nee', status: 'rejected' }], ...extra,
  }
}

Deno.test('a request needs a code of 32 hex characters', () => {
  assertEquals(parseViewRequest({ code: 'ABCDEF0123456789abcdef0123456789' }), { code: 'abcdef0123456789abcdef0123456789', action: 'view', viewer: undefined })
  assertEquals(parseViewRequest({ code: '../etc' }), 'code')
  assertEquals(parseViewRequest(null), 'body')
  const withViewer = parseViewRequest({ code: 'a'.repeat(32), action: 'download', viewer: { name: '  Sanne   de Vries ', organisation: 'x'.repeat(200) } })
  if (typeof withViewer === 'string') throw new Error(withViewer)
  assertEquals(withViewer.action, 'download')
  assertEquals(withViewer.viewer?.name, 'Sanne de Vries')
  assertEquals(withViewer.viewer?.organisation?.length, 80)
})

Deno.test('taken back, ended and paused shares show nothing', () => {
  const now = new Date('2026-12-01T12:00:00Z')
  assertEquals(shareState(share, now), 'active')
  assertEquals(shareState({ ...share, paused_at: '2026-11-30T00:00:00Z' }, now), 'paused')
  assertEquals(shareState({ ...share, expires_at: '2026-12-01T11:59:59Z' }, now), 'expired')
  // Taken back wins over everything else.
  assertEquals(shareState({ ...share, revoked_at: '2026-11-30T00:00:00Z', paused_at: '2026-11-29T00:00:00Z' }, now), 'revoked')
})

Deno.test('only chosen evidence of the owner, as the vault says it now, in the chosen order', () => {
  const items = [
    item('i1', { verification_status: 'verified' }),
    item('i2'),
    item('other', { user_id: '22222222-2222-2222-2222-222222222222' }),
    item('archived', { archived_at: '2026-11-01T00:00:00Z' }),
    item('rejected', { verification_status: 'rejected' }),
  ]
  const shown = chosenItems(share, items)
  assertEquals(shown.map((i) => i.id), ['i2', 'i1'])
  assertEquals(shown[1].verified, true)
  assertEquals(shown[0].verified, false)
  assertEquals(shown[0].skills, ['Swift'])
  assertEquals(shown[0].organisation, 'Pixelwerk, Eindhoven')
})

Deno.test('files only from the share\'s own folder', () => {
  assertEquals(documentPaths(share), [{ kind: 'cv', path: `${owner}/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/cv.pdf` }])
  assertEquals(documentPaths({ ...share, content: { documents: { cv: `${owner}/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/../x.pdf` } } }), [])
})

Deno.test('the profile carries only its known fields', () => {
  const view = shareView(share, [], [])
  assertEquals(view.profile.name, 'Ravi Santoso')
  assertEquals('secret' in view.profile, false)
  assertEquals(view.allowsDownload, false)
  assertEquals(view.recipient, { name: 'Sanne de Vries', organisation: 'Kade Consultancy' })
})

Deno.test('what was shared briefly shows without its description and skills', () => {
  const brief: ShareRow = { ...share, content: { ...share.content, brief: ['i1', 42] } }
  const shown = chosenItems(brief, [item('i1', { description: 'Lang verhaal' }), item('i2', { description: 'Ook lang' })])
  const byId = Object.fromEntries(shown.map((i) => [i.id, i]))
  assertEquals(byId.i1.description, undefined)
  assertEquals(byId.i1.skills, [])
  assertEquals(byId.i1.title, 'Titel i1')
  assertEquals(byId.i2.description, 'Ook lang')
  assertEquals(byId.i2.skills, ['Swift'])
})

Deno.test('files go along only for evidence the owner named, of the owner, and only documents', () => {
  const withFiles: ShareRow = { ...share, content: { ...share.content, files: ['i1', 'i1', 'not-in-share', 7] } }
  assertEquals(fileItemIDs(withFiles), ['i1'])
  const rows: FileRow[] = [
    { id: 'f1', user_id: owner, item_id: 'i1', storage_path: `${owner}/i1/diploma.pdf`, file_name: 'Diploma.pdf', mime_type: 'application/pdf', role: 'document' },
    { id: 'f2', user_id: owner, item_id: 'i1', storage_path: `${owner}/i1/cover.jpg`, file_name: 'cover.jpg', mime_type: 'image/jpeg', role: 'cover' },
    { id: 'f3', user_id: owner, item_id: 'i2', storage_path: `${owner}/i2/brief.pdf`, file_name: 'Brief.pdf', mime_type: 'application/pdf', role: null },
    { id: 'f4', user_id: 'someone-else', item_id: 'i1', storage_path: 'x/i1/a.pdf', file_name: 'a.pdf', mime_type: 'application/pdf', role: 'document' },
  ]
  assertEquals(sharedFiles(withFiles, rows).map((f) => f.id), ['f1'])
  assertEquals(fileItemIDs(share), [])
})

Deno.test('the latest verified decision per item, of the owner, shows only on evidence that is still verified', () => {
  const rows: VerificationRow[] = [
    { item_id: 'i1', user_id: owner, organisation_name: 'Fontys', status: 'verified', resolved_at: '2026-01-10T10:00:00Z' },
    { item_id: 'i1', user_id: owner, organisation_name: 'Fontys Hogescholen', status: 'verified', resolved_at: '2026-01-12T10:00:00Z' },
    { item_id: 'i2', user_id: owner, organisation_name: 'Pixelwerk', status: 'rejected', resolved_at: '2026-01-12T10:00:00Z' },
    { item_id: 'i2', user_id: 'someone-else', organisation_name: 'Nep', status: 'verified', resolved_at: '2026-01-12T10:00:00Z' },
  ]
  const verified = verifications(rows, owner)
  assertEquals(verified.get('i1'), { by: 'Fontys Hogescholen', on: '2026-01-12T10:00:00Z' })
  assertEquals(verified.has('i2'), false)
  const items = chosenItems(share, [item('i1', { verification_status: 'verified' }), item('i2')], new Map([['i1', [{ name: 'Diploma.pdf', mimeType: 'application/pdf', url: 'https://x' }]]]), new Map([...verified, ['i2', { by: 'Nep', on: 'x' }]]))
  assertEquals(items.find((i) => i.id === 'i1')?.verification?.by, 'Fontys Hogescholen')
  assertEquals(items.find((i) => i.id === 'i1')?.files.length, 1)
  assertEquals(items.find((i) => i.id === 'i2')?.verification, undefined)
})
