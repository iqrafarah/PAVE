import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import { test } from 'node:test'
import { answer } from '../brain.ts'
import { parseRequest } from '../contract.ts'
import { openRouterCompletion } from '../openrouter.ts'
import { buildSystemPrompt } from '../prompt.ts'
import { toFoundVacancy } from '../vacancies.ts'

const request = { text: 'Welke banen passen bij mij?', device: 'phone' as const, input: 'text' as const }
const ids = () => { let n = 0; return () => `id_${++n}` }

function model(...outputs: object[]) {
  const calls: { role: string; content: string }[][] = []
  return {
    calls,
    complete: async (messages: { role: string; content: string }[]) => {
      calls.push(messages)
      const next = outputs[calls.length - 1] ?? outputs.at(-1)
      return { model: 'fake', content: JSON.stringify(next) }
    },
  }
}

const say = (text: string, extra: object = {}) => ({ text, question: null, navigation: null, vacancySearch: null, ...extra })

test('a plain answer becomes a reply in the contract format', async () => {
  const fake = model(say('Hoi! Waar wil je mee beginnen?'))
  const reply = await answer({ request, conversationId: 'conv', history: [] }, { complete: fake.complete, newId: ids() })
  assert.deepEqual(reply, { version: 1, id: 'id_1', conversationId: 'conv', text: 'Hoi! Waar wil je mee beginnen?', blocks: [], usedData: [] })
})

test('usedData stays empty because Ayla has no vault access yet', async () => {
  const fake = model(say('Ik kan nog niet in je kluis kijken.'))
  const reply = await answer({ request, conversationId: 'c', history: [] }, { complete: fake.complete, newId: ids() })
  assert.deepEqual(reply.usedData, [])
  assert.match(fake.calls[0][0].content, /geen toegang tot de kluis/)
})

test('the prompt has the device style, the name and the open screen', () => {
  const prompt = buildSystemPrompt({ device: 'watch', firstName: 'Daaf', context: { screen: 'vault' } })
  assert.match(prompt, /Apple Watch/)
  assert.match(prompt, /heet Daaf/)
  assert.match(prompt, /de kluis open/)
})

test('history is sent in order and limited', async () => {
  const fake = model(say('Ok'))
  const history = Array.from({ length: 30 }, (_, i) => ({ role: (i % 2 ? 'ayla' : 'user') as 'user' | 'ayla', text: `m${i}` }))
  await answer({ request, conversationId: 'c', history }, { complete: fake.complete, newId: ids() })
  const sent = fake.calls[0]
  assert.equal(sent.length, 1 + 20 + 1)
  assert.equal(sent[1].content, 'm10')
  assert.equal(sent.at(-1)!.content, request.text)
})

test('a vacancy search shows real results as cards and never invents them', async () => {
  const fake = model(say('', { vacancySearch: { what: 'junior developer', where: 'Eindhoven' } }), say('Ik vond er een.'))
  let searched: string[] = []
  const reply = await answer({ request, conversationId: 'c', history: [] }, {
    complete: fake.complete,
    newId: ids(),
    searchVacancies: async (what, where) => {
      searched = [what, where]
      return [{ vacancy: { id: 'adzuna_1', title: 'Junior developer', company: 'Bedrijf', source: 'adzuna', matches: [], skillGap: [] }, snippet: 'Je bouwt apps.' }]
    },
  })
  assert.deepEqual(searched, ['junior developer', 'Eindhoven'])
  assert.equal(reply.blocks.length, 1)
  assert.equal(reply.blocks[0].type, 'vacancies')
  assert.match(fake.calls[1].at(-1)!.content, /Junior developer bij Bedrijf/)
})

test('without an Adzuna key Ayla says honestly that searching is not set up', async () => {
  const fake = model(say('', { vacancySearch: { what: 'developer', where: '' } }), say('Vacatures zoeken werkt nog niet.'))
  const reply = await answer({ request, conversationId: 'c', history: [] }, { complete: fake.complete, newId: ids() })
  assert.deepEqual(reply.blocks, [])
  assert.match(fake.calls[1].at(-1)!.content, /nog niet ingesteld/)
})

test('the Watch gets no vacancy cards', async () => {
  const fake = model(say('', { vacancySearch: { what: 'developer', where: '' } }), say('Ze staan op je iPhone.'))
  const reply = await answer({ request: { ...request, device: 'watch' }, conversationId: 'c', history: [] }, {
    complete: fake.complete,
    newId: ids(),
    searchVacancies: async () => [{ vacancy: { id: 'a', title: 't', company: 'c', source: 'adzuna', matches: [], skillGap: [] }, snippet: '' }],
  })
  assert.deepEqual(reply.blocks, [])
})

test('choices are capped at three and unknown screens are dropped', async () => {
  const choices = ['Ja', 'Nee', 'Misschien', 'Later'].map((label, i) => ({ id: `c${i}`, label }))
  const fake = model(say('Kies maar.', { question: { text: 'Verder?', choices }, navigation: { screen: 'adminPanel' } }))
  const reply = await answer({ request, conversationId: 'c', history: [] }, { complete: fake.complete, newId: ids() })
  assert.equal(reply.question!.choices.length, 3)
  assert.equal(reply.navigation, undefined)
})

test('navigation to a known screen is passed on', async () => {
  const fake = model(say('Ik open je kluis.', { navigation: { screen: 'vault' } }))
  const reply = await answer({ request, conversationId: 'c', history: [] }, { complete: fake.complete, newId: ids() })
  assert.deepEqual(reply.navigation, { screen: 'vault' })
})

test('text that is not JSON is still shown, without markdown', async () => {
  const reply = await answer({ request, conversationId: 'c', history: [] }, {
    complete: async () => ({ model: 'fake', content: '**Hoi** daar' }),
    newId: ids(),
  })
  assert.equal(reply.text, 'Hoi daar')
})

test('requests are checked', () => {
  assert.equal(typeof parseRequest({ ...request, device: 'tv' }), 'string')
  assert.equal(typeof parseRequest({ ...request, conversationId: 'not-a-uuid' }), 'string')
  assert.equal(typeof parseRequest({ ...request, granted: ['skills'] }), 'string')
  assert.equal(typeof parseRequest({ ...request, text: '   ' }), 'string')
  assert.deepEqual(parseRequest({ ...request, context: { screen: 'vault' } }), { ...request, context: { screen: 'vault' } })
})

test('the example request in shared/ayla is valid', () => {
  const example = JSON.parse(readFileSync(new URL('../../../../ayla/request.example.json', import.meta.url), 'utf8'))
  example.conversationId = '7a1d6c1e-2f4b-4c8e-9d3a-1b2c3d4e5f60'
  assert.equal(typeof parseRequest(example), 'object')
})

test('an Adzuna result becomes a vacancy card with the salary as an estimate', () => {
  const found = toFoundVacancy({
    id: 42, title: '<strong>Junior</strong> developer', company: { display_name: 'Bedrijf' },
    location: { display_name: 'Eindhoven, Noord-Brabant' }, contract_time: 'full_time',
    salary_min: 36000, salary_max: 42000, salary_is_predicted: '1',
    redirect_url: 'https://www.adzuna.nl/details/42', description: 'Je bouwt <b>apps</b>.',
  })!
  assert.equal(found.vacancy.title, 'Junior developer')
  assert.equal(found.vacancy.employment, 'fullTime')
  assert.deepEqual(found.vacancy.salary, { min: 36000, max: 42000, period: 'year', currency: 'EUR', isEstimate: true })
  assert.equal(found.vacancy.source, 'adzuna')
  assert.equal(found.snippet, 'Je bouwt apps.')
})

test('an Adzuna result without salary or contract leaves those fields out', () => {
  const found = toFoundVacancy({ id: 1, title: 'Tester', company: { display_name: 'X' } })!
  assert.equal(found.vacancy.salary, undefined)
  assert.equal(found.vacancy.employment, undefined)
  assert.equal(toFoundVacancy({ id: 2, title: 'Geen bedrijf' }), null)
})

test('a slow model gets a second model alongside it, the first good answer wins', async () => {
  const slow = (ms: number, body: object, ok = true) => new Promise<Response>((resolve) => setTimeout(() => resolve(new Response(JSON.stringify(body), { status: ok ? 200 : 500 })), ms))
  const asked: string[] = []
  const fakeFetch = (async (_url: string, init: RequestInit) => {
    const model = JSON.parse(init.body as string).model
    asked.push(model)
    return model === 'a' ? slow(200, { choices: [{ message: { content: 'langzaam' } }] }) : slow(10, { choices: [{ message: { content: 'snel' } }] })
  }) as typeof fetch
  const complete = openRouterCompletion('key', {}, fakeFetch, ['a', 'b'], 20)
  const result = await complete([{ role: 'user', content: 'hoi' }])
  assert.deepEqual(asked, ['a', 'b'])
  assert.equal(result.content, 'snel')
})

test('a failing model hands over to the next one at once', async () => {
  const fakeFetch = (async (_url: string, init: RequestInit) => {
    const model = JSON.parse(init.body as string).model
    return model === 'a' ? new Response('{}', { status: 503 }) : new Response(JSON.stringify({ choices: [{ message: { content: 'ok' } }] }))
  }) as typeof fetch
  const result = await openRouterCompletion('key', {}, fakeFetch, ['a', 'b'], 10_000)([{ role: 'user', content: 'hoi' }])
  assert.equal(result.model, 'b')
})

test('the model output schema and the shared reply schema agree on screens', () => {
  const schema = JSON.parse(readFileSync(new URL('../../../../ayla/reply.schema.json', import.meta.url), 'utf8'))
  const shared = schema.$defs.screen.enum
  for (const screen of ['home', 'vault', 'addEvidence', 'plans', 'vacancies', 'profile', 'settings']) assert.ok(shared.includes(screen))
  assert.ok(readdirSync(new URL('../../../../ayla/examples', import.meta.url)).length > 0)
})
