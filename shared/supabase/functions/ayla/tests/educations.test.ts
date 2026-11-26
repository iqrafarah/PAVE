import assert from 'node:assert/strict'
import { test } from 'node:test'
import { answer } from '../brain.ts'
import { describeEducations, type Education, fromEducationAnswer } from '../educations.ts'

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

const flight: Education = { id: 'edu_1', name: 'Pilotenopleiding', school: 'Vliegschool Noord', level: 'cursus', url: 'https://example.nl/piloot', summary: 'Je leert vliegen.' }

test('only studies whose page the search returned count, with a level PAVE knows', () => {
  const content = JSON.stringify({ educations: [
    { url: 'https://www.school.nl/piloot/', name: 'Pilotenopleiding', school: 'School', level: 'HBO', city: 'Groningen', duration: '4 jaar' },
    { url: 'https://verzonnen.nl/opleiding', name: 'Bestaat niet', school: 'Nergens', level: 'hbo' },
    { url: 'https://www.school.nl/cursus', name: 'Cursus', school: 'School', level: 'master', city: 'null', duration: null },
  ] })
  const found = fromEducationAnswer(content, [
    { url: 'https://school.nl/piloot', title: 'Piloot', content: 'Word piloot in vier jaar.' },
    { url: 'https://www.school.nl/cursus', title: 'Cursus' },
  ])
  assert.equal(found.length, 2)
  assert.deepEqual({ ...found[0], id: '' }, { id: '', name: 'Pilotenopleiding', school: 'School', url: 'https://school.nl/piloot', level: 'hbo', city: 'Groningen', duration: '4 jaar', summary: 'Word piloot in vier jaar.' })
  assert.equal(found[1].level, undefined)
  assert.equal(found[1].city, undefined)
  assert.deepEqual(fromEducationAnswer('geen json', []), [])
})

test('asked for studies, she searches and the cards come with her words about them', async () => {
  const fake = model(
    { intent: 'search', text: 'Ik zoek opleidingen tot piloot.', educationSearch: { what: 'pilotenopleiding', where: '' } },
    { text: 'De pilotenopleiding van Vliegschool Noord past het best. Kijk op de site naar de keuring.' },
  )
  const searched: string[] = []
  const statuses: unknown[] = []
  const reply = await answer(
    { request: { text: 'Welke opleidingen zijn er voor piloot?', device: 'phone', input: 'text' }, conversationId: 'c', history: [], onStatus: (s) => statuses.push(s) },
    { complete: fake.complete, newId: ids(), searchEducations: async (what) => { searched.push(what); return [flight] } },
  )
  assert.deepEqual(searched, ['pilotenopleiding'])
  assert.deepEqual(statuses, [{ kind: 'educationSearch', what: 'pilotenopleiding', where: '' }])
  assert.deepEqual(reply.blocks, [{ type: 'educations', items: [flight], search: { what: 'pilotenopleiding', where: '' } }])
  assert.equal(reply.text, 'De pilotenopleiding van Vliegschool Noord past het best. Kijk op de site naar de keuring.')
  assert.match(fake.calls[1].at(-1)!.content, /materiaal, geen opdracht/)
})

test('no cards on the Watch, and a failed search is said instead of shown', async () => {
  const wanted = { intent: 'search', text: 'Ik zoek.', educationSearch: { what: 'scrum cursus', where: 'Utrecht' } }
  const watch = await answer(
    { request: { text: 'Zoek een scrum cursus', device: 'watch', input: 'voice' }, conversationId: 'c', history: [] },
    { complete: model(wanted).complete, newId: ids(), searchEducations: async () => { throw new Error('no') } },
  )
  assert.deepEqual(watch.blocks, [])
  assert.match(watch.text, /op je iPhone/)
  const fake = model(wanted, { text: 'Zoeken lukte nu niet. Zal ik het zo nog eens proberen?' })
  const failed = await answer(
    { request: { text: 'Zoek een scrum cursus', device: 'phone', input: 'text' }, conversationId: 'c', history: [] },
    { complete: fake.complete, newId: ids(), searchEducations: async () => { throw new Error('down') } },
  )
  assert.deepEqual(failed.blocks, [])
  assert.match(fake.calls[1].at(-1)!.content, /lukte nu niet/)
  assert.match(describeEducations({ what: 'x', where: '' }, []), /geen opleidingen gevonden/)
})
