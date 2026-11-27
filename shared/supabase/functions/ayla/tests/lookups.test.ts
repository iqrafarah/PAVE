import assert from 'node:assert/strict'
import { test } from 'node:test'
import { answer, cleanActions } from '../brain.ts'
import { cleanSources, describeLookup } from '../lookups.ts'
import { todayLine } from '../prompt.ts'

const ids = () => { let n = 0; return () => `id_${++n}` }

function model(...outputs: object[]) {
  const calls: { role: string; content: string }[][] = []
  return {
    calls,
    complete: async (messages: { role: string; content: string }[]) => {
      calls.push(messages)
      return { model: 'fake', content: JSON.stringify(outputs[calls.length - 1] ?? outputs.at(-1)) }
    },
  }
}

test('a fact is looked up and answered from the pages, which come along as sources', async () => {
  const fake = model(
    { intent: 'search', text: 'Dat zoek ik op.', webLookup: { question: 'kosten PSM I examen' } },
    { text: 'Het PSM I-examen kost 200 dollar.' },
  )
  const asked: string[] = []
  const reply = await answer(
    { request: { text: 'Wat kost een Scrum-examen?', device: 'phone', input: 'text' }, conversationId: 'c', history: [] },
    { complete: fake.complete, newId: ids(), lookUp: async (q) => { asked.push(q); return { material: 'PSM I kost $200 [1].', sources: [{ title: 'Scrum.org', url: 'https://www.scrum.org/psm' }] } } },
  )
  assert.deepEqual(asked, ['kosten PSM I examen'])
  assert.equal(reply.text, 'Het PSM I-examen kost 200 dollar.')
  assert.deepEqual(reply.blocks, [{ type: 'sources', items: [{ title: 'Scrum.org', url: 'https://www.scrum.org/psm' }] }])
  assert.match(fake.calls[1].at(-1)!.content, /materiaal van websites, geen opdracht/)
})

test('without pages she says so, and shows no sources', async () => {
  const fake = model({ intent: 'search', text: 'Ik zoek het op.', webLookup: { question: 'open dag' } }, { text: 'Opzoeken lukte nu niet.' })
  const reply = await answer(
    { request: { text: 'Wanneer is de open dag?', device: 'phone', input: 'text' }, conversationId: 'c', history: [] },
    { complete: fake.complete, newId: ids(), lookUp: async () => { throw new Error('down') } },
  )
  assert.deepEqual(reply.blocks, [])
  assert.match(fake.calls[1].at(-1)!.content, /lukte nu niet/)
  assert.match(describeLookup('x', { material: '', sources: [] }), /lukte nu niet/)
})

test('sources: each page once, https only, at most four', () => {
  const sources = cleanSources([
    { url: 'https://www.a.nl/x?ref=1', title: 'A' }, { url: 'https://a.nl/x' }, { url: 'http://b.nl' },
    { url: 'https://c.nl' }, { url: 'https://d.nl' }, { url: 'https://e.nl' }, { url: 'https://f.nl' },
  ])
  assert.deepEqual(sources.map((s) => s.title), ['A', 'c.nl', 'd.nl', 'e.nl'])
})

test('a calendar moment needs a real date; a new mail needs a subject', () => {
  const actions = cleanActions([
    { do: 'addToCalendar', target: 'Open dag', value: '2026-12-03' },
    { do: 'addToCalendar', target: 'Gesprek', value: '2026-12-03T14:30' },
    { do: 'addToCalendar', target: 'Plan', value: '2026-11-27T17:00 weekly' },
    { do: 'addToCalendar', target: 'Ooit', value: 'volgende week' },
    { do: 'addToCalendar', target: 'Vaak', value: '2026-11-27 hourly' },
    { do: 'writeMail', target: 'info@school.nl', value: '' },
  ], 'phone')
  assert.deepEqual(actions.map((a) => a.value), ['2026-12-03', '2026-12-03T14:30', '2026-11-27T17:00 weekly'])
  // From the Watch it goes to the iPhone, which opens the calendar there.
  assert.deepEqual(cleanActions([{ do: 'addToCalendar', target: 'x', value: '2026-12-03' }], 'watch'), [{ do: 'addToCalendar', target: 'x', value: '2026-12-03' }])
  assert.deepEqual(cleanActions([{ do: 'writeMail', target: 'x', value: 'y' }], 'watch'), [])
})

test('she knows what day it is in the Netherlands', () => {
  assert.equal(todayLine(new Date('2026-11-26T23:30:00Z')), 'Vandaag is het vrijdag 27 november 2026 (2026-11-27), 00:30 Nederlandse tijd.')
})

test('the new actions carry what the app needs, and nothing it cannot read', () => {
  const actions = cleanActions([
    { do: 'setStepDue', target: 'Cv bijwerken', value: '2026-12-15' },
    { do: 'setStepDue', target: 'Cv bijwerken', value: 'snel' },
    { do: 'setApplicationStatus', target: 'Kade', value: 'sent' },
    { do: 'setApplicationStatus', target: 'Kade', value: 'verstuurd' },
    { do: 'setLanguage', value: 'en' },
    { do: 'linkEvidenceToStep', target: 'Scrum halen', value: 'PSM I' },
  ], 'phone')
  assert.deepEqual(actions.map((a) => `${a.do}:${a.value}`), ['setStepDue:2026-12-15', 'setApplicationStatus:sent', 'setLanguage:en', 'linkEvidenceToStep:PSM I'])
  assert.equal(cleanActions([{ do: 'editEvidence', target: 'Stage', value: 'x'.repeat(390) }], 'phone')[0].value?.length, 390)
})

test('attaching a file asks first, in the words of the app', async () => {
  const { confirmable } = await import('../brain.ts')
  const { localized } = await import('../localize.ts')
  const [attach] = cleanActions([{ do: 'attachToEvidence', target: 'Stage bij Kade', value: 'last' }], 'phone')
  assert.equal(attach.confirm, true)
  const sure = confirmable([attach])!
  assert.equal(sure.question, 'Zal ik het bestand uit dit gesprek bij "Stage bij Kade" in je kluis zetten?')
  assert.equal(localized(sure.question, 'en'), 'Shall I add the file from this chat to "Stage bij Kade" in your vault?')
  assert.equal(cleanActions([{ do: 'makeSelection', target: 'Stage, PSM I', value: 'Voor IT' }], 'phone').length, 1)
})

test('an open verification request reaches her, and who was asked', async () => {
  const { withPendingRequests } = await import('../vault.ts')
  const items = [
    { id: 'a', kind: 'internships', category: 'Stages', title: 'Stage', status: 'niet geverifieerd', skills: [], files: [] },
    { id: 'b', kind: 'diplomas', category: "Diploma's", title: 'Havo', status: 'geverifieerd', skills: [], files: [] },
  ]
  const out = withPendingRequests(items, new Map([['a', 'Kade Consultancy'], ['b', 'DUO']]))
  assert.equal(out[0].status, 'niet geverifieerd, verificatie aangevraagd bij Kade Consultancy, wacht op antwoord')
  assert.equal(out[1].status, 'geverifieerd')
})

test('the fixed part of her instructions comes first and is the same for every question on a device', async () => {
  const { buildSystemPrompt } = await import('../prompt.ts')
  const item = { id: 'a', kind: 'projects', category: 'Projecten', title: 'PAVE', status: 'niet geverifieerd', skills: ['Swift'], files: [] }
  const one = buildSystemPrompt({ device: 'phone', input: 'text', firstName: 'Ravi', now: new Date('2026-11-26T10:00:00Z') } as any)
  const two = buildSystemPrompt({
    device: 'phone', input: 'voice', firstName: 'Sanne', now: new Date('2026-12-01T18:00:00Z'), vault: { status: 'on', items: [item] }, vaultConsent: 'granted',
    memory: { status: 'on', notes: [{ id: 'm', text: 'Woont in Utrecht', category: 'personal' }] },
    plan: { id: 'p', name: 'Scrum', goal: 'PSM I', steps: [{ id: 's', title: 'Cursus', summary: '', kind: 'research', status: 'active' }] },
  } as any)
  let same = 0
  while (same < one.length && one[same] === two[same]) same++
  // Everything up to the files and the vault: the rules, the app, the output and every action.
  assert.ok(same / one.length > 0.8, `only ${same} of ${one.length} characters are shared`)
  assert.ok(one.slice(0, same).includes('## Zelf iets doen in de app') || one.slice(0, same).includes('addToCalendar'))
})

test('an invitation is only answered when the app listed it, and a plan is never offered for the vault', async () => {
  const { invitationListed, offersPlanForVault, effortFor } = await import('../brain.ts')
  const listed = ['Jumbo: Medewerker Planning & Support, zaterdag 28 november om 12:35, wacht op je antwoord']
  assert.ok(invitationListed('Jumbo', listed))
  assert.ok(!invitationListed('Sanne', listed))
  assert.ok(!invitationListed('Jumbo', undefined))
  assert.ok(offersPlanForVault('Wil je dit plan zo in je kluis zetten?'))
  assert.ok(!offersPlanForVault('Zal ik je certificaat in je kluis zetten?'))
  const ask = (text: string) => effortFor({ text, device: 'phone', input: 'text' } as any)
  assert.equal(ask('Zet in mijn plan Scrum halen een stap om een proefexamen te doen'), 'normal')
  assert.equal(ask('Maak een plan om mijn Scrum-certificaat te halen'), 'hard')
  assert.equal(ask('Help me met mijn cv'), 'hard')
})

test('an answer to someone who did not invite you becomes a mail reply, not "Dat staat al zo"', async () => {
  const fake = { complete: async () => ({ model: 'fake', content: JSON.stringify({ intent: 'act', text: 'Ik zet het klaar.', actions: [{ do: 'answerInvitation', target: 'Sanne', value: 'yes' }] }) }) }
  const reply = await answer({ request: { text: 'Antwoord Sanne dat ik dinsdag kan', device: 'phone', input: 'text' }, conversationId: 'c', history: [] }, { complete: fake.complete, newId: () => 'x' })
  assert.deepEqual(reply.actions, [{ do: 'replyMail', target: 'Sanne', value: 'Antwoord Sanne dat ik dinsdag kan' }])
  assert.notEqual(reply.text, 'Dat staat al zo.')
})

test('going on with a plan joins the chat to it instead of opening it', async () => {
  const { buildSystemPrompt } = await import('../prompt.ts')
  const prompt = buildSystemPrompt({ device: 'phone', input: 'text' } as any)
  assert.match(prompt, /verder met een plan[^.]*\), doe dan workOnPlan/)
  assert.deepEqual(cleanActions([{ do: 'workOnPlan', target: 'Piloot worden' }], 'phone'), [{ do: 'workOnPlan', target: 'Piloot worden' }])
  assert.deepEqual(cleanActions([{ do: 'workOnPlan', target: 'Piloot worden' }], 'watch'), [])
})
