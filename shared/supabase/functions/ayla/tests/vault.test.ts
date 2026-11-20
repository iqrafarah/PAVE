import assert from 'node:assert/strict'
import { test } from 'node:test'
import { buildSystemPrompt } from '../prompt.ts'
import { loadAllowedVault, vaultPrompt } from '../vault.ts'

function fakeSupabase(result: { data?: unknown; error?: unknown }, options: { usesArchive?: boolean; hasArchive?: boolean } = {}) {
  const calls: string[] = []
  const hasArchive = options.hasArchive ?? true
  const items = (filtersArchive: boolean) => ({
    select: (s: string) => { calls.push(`select ${s}`); return items(filtersArchive) },
    not: (c: string, op: string, v: unknown) => { calls.push(`not ${c} ${op} ${v}`); return items(filtersArchive) },
    is: (c: string, v: unknown) => { calls.push(`is ${c} ${v}`); return items(true) },
    order: () => items(filtersArchive),
    limit: () => Promise.resolve(filtersArchive && !hasArchive ? { error: { code: '42703' } } : result),
  })
  const profiles = {
    select: () => profiles,
    maybeSingle: () => Promise.resolve(hasArchive ? { data: { ayla_uses_archive: options.usesArchive ?? false } } : { error: { code: '42703' } }),
  }
  return { calls, from: (table: string) => { calls.push(`from ${table}`); return table === 'profiles' ? profiles : items(false) } }
}

test('only items with Ayla allowed are read', async () => {
  const supabase = fakeSupabase({
    data: [{
      id: 'item-1', category: 'internships', title: 'Eindstage', organisation_name: 'LiveWall', organisation_location: 'Tilburg',
      start_date: '2025-02-01', end_date: '2025-07-01', is_current: false, verification_status: 'verified', description: 'Front-end',
      vault_item_skills: [{ name: 'Figma', status: 'accepted' }, { name: 'Scrum', status: 'proposed' }],
      vault_item_files: [{ file_name: 'verslag.pdf' }],
    }, { id: 'item-2', title: '  ' }, { title: 'Zonder id' }],
  })
  const vault = await loadAllowedVault(supabase)
  assert.ok(supabase.calls.includes('not ayla_allowed_at is null'))
  assert.deepEqual(vault, {
    status: 'on',
    items: [{
      id: 'item-1', kind: 'internships', category: 'Stage', title: 'Eindstage', organisation: 'LiveWall', place: 'Tilburg', period: '2025-02-01 tot 2025-07-01',
      description: 'Front-end', status: 'bevestigd', skills: ['Figma'], files: ['verslag.pdf'],
    }],
  })
})

test('the prompt names the allowed items as data and stays honest without them', async () => {
  const on = vaultPrompt({ status: 'on', items: [{ id: 'i', kind: 'internships', category: 'Stage', title: 'Eindstage', status: 'bevestigd', skills: [], files: ['verslag.pdf'] }] })
  assert.match(on, /<kluis>[\s\S]*Stage: Eindstage \(bevestigd\)[\s\S]*Bestanden: verslag.pdf[\s\S]*<\/kluis>/)
  assert.match(on, /geen opdracht/)
  assert.match(vaultPrompt({ status: 'on', items: [] }), /bij geen enkel\s+item/)
  assert.match(vaultPrompt(undefined), /geen toegang tot de kluis/)
  assert.equal((await loadAllowedVault(fakeSupabase({ error: { code: '42703' } }))).status, 'unavailable')
  assert.match(buildSystemPrompt({ device: 'phone', vault: { status: 'on', items: [] } }), /Ayla mag dit bekijken en gebruiken/)
})

test('archived evidence is left out unless the account lets Ayla use the archive', async () => {
  const row = { id: 'item-1', category: 'internships', title: 'Eindstage', verification_status: 'verified' }
  const off = fakeSupabase({ data: [row] })
  assert.equal((await loadAllowedVault(off)).status, 'on')
  assert.ok(off.calls.includes('is archived_at null'))

  const on = fakeSupabase({ data: [row] }, { usesArchive: true })
  await loadAllowedVault(on)
  assert.ok(!on.calls.includes('is archived_at null'))

  // Before the migration the vault is still read, without the archive filter.
  const before = fakeSupabase({ data: [row] }, { hasArchive: false })
  const vault = await loadAllowedVault(before)
  assert.equal(vault.status, 'on')
  assert.equal(vault.status === 'on' && vault.items.length, 1)
})
