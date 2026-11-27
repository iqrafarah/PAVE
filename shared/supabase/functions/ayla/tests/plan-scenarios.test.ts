// Many everyday situations around a plan, each answered by a model that does everything wrong at once: it makes a
// plan again, proposes changes, opens the plan's page, takes out "a step" that is the plan itself and asks two
// questions. Whatever the model does, what goes to the app must hold to the rules below. No real model is called.
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { answer, type PastMessage, toPastMessage } from '../brain.ts'
import type { AylaReply, AylaRequest } from '../contract.ts'
import type { PlanContext } from '../plan.ts'

const plan: PlanContext = {
  id: 'plan',
  name: 'KLM-piloot worden',
  goal: 'Ik wil KLM-piloot worden.',
  steps: [
    { id: 's1', title: 'Eisen van de KLM Flight Academy uitzoeken', summary: '', kind: 'research', status: 'done' },
    { id: 's2', title: 'Cursus natuurkunde volgen', summary: '', kind: 'action', status: 'active' },
    { id: 's3', title: 'Engelse taaltoets doen', summary: '', kind: 'action', status: 'upcoming' },
    { id: 's4', title: 'Aanmelden', summary: '', kind: 'milestone', status: 'upcoming' },
  ],
}
const app = { plans: ['KLM-piloot worden (1 van 4 stappen, nu: Cursus natuurkunde volgen)', 'Scrum halen (0 van 3 stappen, nu: Cursus kiezen)'], projects: [] }

/** Everything at once, as a model that follows none of its rules. */
const everything = (text: string) => ({
  intent: 'act',
  text,
  question: { text: 'Waar wil je mee beginnen?', choices: [{ id: 'a', label: 'Cursus natuurkunde' }, { id: 'b', label: 'Engelse taaltoets' }] },
  navigation: null, vacancySearch: null, educationSearch: null, webLookup: null, title: null, askVault: null, vaultItem: null,
  actions: [{ do: 'openPlan', value: null, target: 'KLM-piloot worden' }],
  continues: false, usedVaultItems: [], usedMemories: [], memories: [],
  planStep: { step: 2, status: 'done' },
  planEdit: { changes: [
    { op: 'add', step: 0, title: 'Medische keuring doen', kind: 'action', after: 2, why: 'De opleiding vraagt hem.' },
    { op: 'add', step: 0, title: 'Aanmelden', kind: 'action', after: 4, why: 'Staat er al.' },
    { op: 'remove', step: 1, title: '', kind: 'general', after: 0, why: 'Is al klaar.' },
    { op: 'remove', step: 3, title: '', kind: 'general', after: 0, why: 'Je hebt al een certificaat.' },
    { op: 'move', step: 4, title: '', kind: 'general', after: 0, why: 'Eerst aanmelden.' },
    { op: 'add', step: 0, title: 'Open dag bezoeken', kind: 'action', after: 1, why: '' },
    { op: 'add', step: 0, title: 'Simulator proberen', kind: 'action', after: 1, why: '' },
  ] },
  newPlan: { name: 'KLM-piloot worden', goal: 'Ik wil KLM-piloot worden.', steps: [{ title: 'Eisen uitzoeken', summary: '', kind: 'research' }, { title: 'Aanmelden', summary: '', kind: 'action' }, { title: 'Keuring', summary: '', kind: 'action' }] },
})

const ids = () => { let n = 0; return () => `id_${++n}` }
const fake = (output: object) => ({ complete: async () => ({ model: 'fake', content: JSON.stringify(output) }), newId: ids(), updatePlanStep: async () => true })
const request = (text: string, more: Partial<AylaRequest> = {}): AylaRequest => ({ text, device: 'phone', input: 'text', app, ...more } as AylaRequest)

const SAID = 'Je mist dus nog natuurkunde en een Engelse taaltoets. Zal ik zoeken naar een cursus natuurkunde?'

/** What every answer about a plan must hold to, whatever the model wrote. */
function holds(reply: AylaReply, text: string, where: { inPlan: boolean; device: string }, label: string) {
  const actions = reply.actions ?? []
  // One question at a time.
  if (reply.question?.text) assert.ok(!reply.text.trim().endsWith('?'), `${label}: twee vragen in één antwoord: "${reply.text}"`)
  // The plan's page only opens when asked to see it.
  if (!/\b(open|bekijk|laat .*zien|toon|zien|show)\b/i.test(text)) assert.ok(!actions.some((a) => a.do === 'openPlan'), `${label}: opent het plan zonder dat het gevraagd is`)
  // No second plan with a name that is there, and none beside the plan of the conversation.
  if (!/\b(nieuw|opnieuw|ander)\w*/i.test(text)) assert.notEqual(reply.proposedAction?.kind, 'createPlan', `${label}: maakt het plan opnieuw`)
  // Changes to the plan: only on the iPhone in a plan, a few, never a done step or a step that is there.
  if (reply.planEdit) {
    assert.ok(where.inPlan && where.device === 'phone', `${label}: planvoorstel waar het niet hoort`)
    assert.ok(reply.planEdit.changes.length <= 4, `${label}: te veel wijzigingen`)
    for (const change of reply.planEdit.changes) {
      assert.notEqual(change.stepId, 's1', `${label}: raakt een afgeronde stap`)
      if (change.op === 'add') assert.notEqual(change.title, 'Aanmelden', `${label}: stap die er al is`)
    }
  }
  // While PAVE waits for a Ja, nothing else changes.
  if (actions.some((a) => a.confirm)) {
    assert.equal(reply.planEdit, undefined, `${label}: voorstel tijdens een Ja/Nee-vraag`)
    assert.equal(reply.proposedAction, undefined, `${label}: wijziging tijdens een Ja/Nee-vraag`)
    assert.equal(actions.length, 1, `${label}: een Ja doet meer dan gevraagd`)
  }
  assert.ok(!/[{}]|\*\*/.test(reply.text), `${label}: ruwe opmaak in de tekst`)
  // A step is only done when the user's words say so.
  if (reply.proposedAction?.kind === 'updatePlan') assert.ok(DONE_WORDS.test(text), `${label}: stap afgerond zonder dat de gebruiker het zei`)
  // A proposal for the plan only when the turn is about the plan.
  if (reply.planEdit) assert.ok(PLAN_WORDS.test(text) || DONE_WORDS.test(text), `${label}: planvoorstel bij een losse opmerking`)
}

const DONE_WORDS = /\b(af|klaar|gedaan|afgerond)\b/i
const PLAN_WORDS = /\b(plan|stap|doel|mis|haal ik|aanmelden als eerste|deze stap)\b/i

const SITUATIONS = [
  'Ik ben er nog niet aan begonnen', 'Top', 'Dankjewel, tot morgen', 'Wat een gedoe zeg', 'Mijn cursus natuurkunde is klaar',
  'Kunnen we weer verder gaan met mijn plan?', 'Ga maar verder', 'Ja', 'Ja, dat had ik net ook al gevraagd.', 'Oké, duidelijk.', 'Nee, laat maar zo',
  'Wat mis ik nog om piloot te worden?', 'Ik heb de cursus natuurkunde af', 'Die stap sla ik over', 'Cursus natuurkunde', 'Engelse taaltoets',
  'Welke opleidingen zijn er?', 'Wat kost de medische keuring?', 'Kijk mijn plan na: haal ik zo mijn doel? Stel voor wat erbij moet of weg kan.',
  'Voeg een stap toe: open dag bezoeken', 'Haal de stap Engelse taaltoets weg', 'Zet aanmelden als eerste', 'Wanneer moet ik me aanmelden?',
  'Bedankt!', 'Hoe laat is het?', 'Wat heb ik al in mijn kluis?', 'Zet het in mijn agenda', 'Mail de school', 'Open mijn plan', 'Laat het plan even zien',
  'Wat is de volgende stap?', 'Ik weet het even niet meer', 'Kun je het korter zeggen?', 'En daarna?', 'Help me met deze stap',
]

test('in every situation around a plan the app only gets what the rules allow', async () => {
  for (const text of SITUATIONS) {
    for (const where of [{ inPlan: true, device: 'phone' }, { inPlan: false, device: 'phone' }, { inPlan: true, device: 'watch' }, { inPlan: true, device: 'web' }] as const) {
      for (const history of [[], [{ role: 'ayla' as const, text: 'Ik stel een aanpassing van je plan voor. Zal ik het plan zo aanpassen?' }]] as PastMessage[][]) {
        const reply = await answer(
          { request: request(text, { device: where.device }), conversationId: 'c', history, ...(where.inPlan ? { plan } : {}) },
          fake(everything(SAID)),
        )
        holds(reply, text, where, `"${text}" (${where.device}${where.inPlan ? ', in plan' : ''}${history.length ? ', na voorstel' : ''})`)
      }
    }
  }
})

test('a whole conversation with a model that makes the plan in every turn makes it once', async () => {
  const turns = ['Ik wil KLM-piloot worden, maak een plan', 'Ja', 'Oké, duidelijk.', 'Cursus natuurkunde', 'Wat kost dat?', 'Ja, doe maar', 'Ga verder', 'Wat is de volgende stap?', 'Bedankt', 'Kunnen we verder met mijn plan?']
  const history: PastMessage[] = []
  let made = 0
  let inPlan = false
  for (const text of turns) {
    // The app lists the plan once it is made, and the conversation then belongs to it.
    const reply = await answer(
      { request: request(text, { app: { plans: made ? ['KLM-piloot worden (0 van 3 stappen, nu: Eisen uitzoeken)'] : [], projects: [] } }), conversationId: 'c', history: [...history], ...(inPlan ? { plan } : {}) },
      fake({ ...everything('Je plan staat klaar. Je mist nog natuurkunde.'), actions: [], planEdit: null, planStep: null, question: null }),
    )
    if (reply.proposedAction?.kind === 'createPlan') { made++; inPlan = true }
    history.push({ role: 'user', text }, toPastMessage({ role: 'ayla', text: reply.text, reply }))
  }
  assert.equal(made, 1)
})

test('the same holds when the app has not listed the new plan yet and the chat is not in it yet', async () => {
  const history: PastMessage[] = []
  let made = 0
  for (const text of ['Maak een plan om KLM-piloot te worden', 'Oké, duidelijk.', 'Cursus natuurkunde', 'Ja']) {
    const reply = await answer({ request: request(text, { app: { plans: [], projects: [] } }), conversationId: 'c', history: [...history] }, fake({ ...everything('Klaar.'), actions: [], planEdit: null, planStep: null, question: null }))
    if (reply.proposedAction?.kind === 'createPlan') made++
    history.push({ role: 'user', text }, toPastMessage({ role: 'ayla', text: reply.text, reply }))
  }
  assert.equal(made, 1)
})

test('deleting a plan and starting over: one Ja/Nee question, then the new plan, once', async () => {
  const history: PastMessage[] = []
  const wrong = { ...everything('Je hebt al een plan. Wil je dat plan verwijderen en een nieuw plan starten?'), question: { text: 'Wil je het plan verwijderen en een nieuw plan starten?', choices: [{ id: 'y', label: 'Ja' }, { id: 'n', label: 'Nee' }] }, actions: [{ do: 'removePlanStep', value: null, target: 'KLM-piloot worden' }], planEdit: null, planStep: null }
  const first = await answer({ request: request('Kunnen we mijn plan van piloot verwijderen en een nieuwe starten?'), conversationId: 'c', history }, fake(wrong))
  assert.deepEqual(first.actions, [{ do: 'deletePlan', target: 'KLM-piloot worden', confirm: true }])
  assert.equal(first.text, 'Zal ik je plan "KLM-piloot worden" verwijderen? Je gesprekken blijven bewaard.')
  assert.equal(first.proposedAction, undefined)
  history.push({ role: 'user', text: 'Kunnen we mijn plan van piloot verwijderen en een nieuwe starten?' }, toPastMessage({ role: 'ayla', text: first.text, reply: first }))
  // The app took the plan away after Ja and asked what the new one is about.
  const gone = { plans: ['Scrum halen (0 van 3 stappen, nu: Cursus kiezen)'], projects: [] }
  const second = await answer({ request: request('Ik wil KLM-piloot worden', { app: gone }), conversationId: 'c', history: [...history] }, fake({ ...everything('Je plan staat klaar.'), actions: [], planEdit: null, planStep: null, question: null }))
  assert.equal(second.proposedAction?.kind, 'createPlan')
  history.push({ role: 'user', text: 'Ik wil KLM-piloot worden' }, toPastMessage({ role: 'ayla', text: second.text, reply: second }))
  const third = await answer({ request: request('Oké, duidelijk.', { app: gone }), conversationId: 'c', history: [...history] }, fake({ ...everything('Je mist nog natuurkunde.'), actions: [], planEdit: null, planStep: null, question: null }))
  assert.equal(third.proposedAction, undefined)
})

test('asking for a plan that is already there goes on with that plan', async () => {
  const reply = await answer({ request: request('Maak een plan om KLM-piloot te worden'), conversationId: 'c', history: [] }, fake({ ...everything('Je plan staat klaar.'), actions: [], planEdit: null, planStep: null, question: null }))
  assert.equal(reply.proposedAction, undefined)
  assert.deepEqual(reply.actions, [{ do: 'workOnPlan', target: 'KLM-piloot worden' }])
})
