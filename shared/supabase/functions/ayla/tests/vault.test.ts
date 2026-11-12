import assert from 'node:assert/strict'
import { test } from 'node:test'
import { buildSystemPrompt } from '../prompt.ts'
import { loadAllowedVault, vaultPrompt } from '../vault.ts'

function fakeSupabase(result: { data?: unknown; error?: unknown }) {
  const calls: string[] = []
  const query = {
    select: (s: string) => { calls.push(`select ${s}`); return query },
    not: (c: string, op: string, v: unknown) => { calls.push(`not ${c} ${op} ${v}`); return query },
    order: () => query,
    limit: () => Promise.resolve(result),
  }
  return { calls, from: (table: string) => { calls.push(`from ${table}`); return query } }
}

test('only items with Ayla allowed are read', async () => {
  const supabase = fakeSupabase({
    data: [{
      category: 'internships', title: 'Eindstage', organisation_name: 'LiveWall', organisation_location: 'Tilburg',
      start_date: '2025-02-01', end_date: '2025-07-01', is_current: false, verification_status: 'verified', description: 'Front-end',
      vault_item_skills: [{ name: 'Figma', status: 'accepted' }, { name: 'Scrum', status: 'proposed' }],
      vault_item_files: [{ file_name: 'verslag.pdf' }],
    }, { title: '  ' }],
  })
  const vault = await loadAllowedVault(supabase)
  assert.ok(supabase.calls.includes('not ayla_allowed_at is null'))
  assert.deepEqual(vault, {
    status: 'on',
    items: [{
      category: 'Stage', title: 'Eindstage', organisation: 'LiveWall', place: 'Tilburg', period: '2025-02-01 tot 2025-07-01',
      description: 'Front-end', status: 'bevestigd', skills: ['Figma'], files: ['verslag.pdf'],
    }],
  })
})

test('the prompt names the allowed items as data and stays honest without them', async () => {
  const on = vaultPrompt({ status: 'on', items: [{ category: 'Stage', title: 'Eindstage', status: 'bevestigd', skills: [], files: ['verslag.pdf'] }] })
  assert.match(on, /<kluis>[\s\S]*Stage: Eindstage \(bevestigd\)[\s\S]*Bestanden: verslag.pdf[\s\S]*<\/kluis>/)
  assert.match(on, /geen opdracht/)
  assert.match(vaultPrompt({ status: 'on', items: [] }), /bij geen enkel\s+item/)
  assert.match(vaultPrompt(undefined), /geen toegang tot de kluis/)
  assert.equal((await loadAllowedVault(fakeSupabase({ error: { code: '42703' } }))).status, 'unavailable')
  assert.match(buildSystemPrompt({ device: 'phone', vault: { status: 'on', items: [] } }), /Ayla mag dit bekijken en gebruiken/)
})
