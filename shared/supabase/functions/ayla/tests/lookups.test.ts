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
    { do: 'addToCalendar', target: 'Ooit', value: 'volgende week' },
    { do: 'writeMail', target: 'info@school.nl', value: '' },
  ], 'phone')
  assert.deepEqual(actions.map((a) => a.value), ['2026-12-03', '2026-12-03T14:30'])
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
