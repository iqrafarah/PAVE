import assert from 'node:assert/strict'
import { test } from 'node:test'
import { localized, localizedReply } from '../localize.ts'
import { confirmable, withoutConsentAsk } from '../brain.ts'
import { cleanPurpose, consentQuestion, saysNo, saysYes } from '../consent.ts'

test('fixed sentences follow the language of the app and leave Dutch alone', () => {
  assert.equal(localized('Zal ik je uitloggen?', 'en'), 'Shall I sign you out?')
  assert.equal(localized('Zal ik je uitloggen?', 'nl'), 'Zal ik je uitloggen?')
  assert.equal(localized('Zal ik je uitloggen?', undefined), 'Zal ik je uitloggen?')
  assert.equal(localized('Iets wat het model schreef.', 'en'), 'Iets wat het model schreef.')
  assert.equal(localized(consentQuestion(cleanPurpose('to see which skills you have')!), 'en'), 'May I look in your vault to see which skills you have?')
  assert.equal(localized('Stap "Cursus kiezen" afgerond', 'pap'), 'Paso "Cursus kiezen" kla')
  assert.equal(localized("Stagebewijs in je kluis zetten bij Stages", 'en'), 'Put Stagebewijs in your vault under Internships')
})

test('a question about several items names them in the language', () => {
  const sure = confirmable([
    { do: 'deleteEvidence', target: 'Diploma', confirm: true },
    { do: 'deleteEvidence', target: 'Stage', confirm: true },
  ] as Parameters<typeof confirmable>[0])
  assert.equal(localized(sure!.question, 'en'), 'Shall I delete "Diploma" and "Stage" from your vault? This cannot be undone.')
})

test('the reply leaves with Yes and No, and the ids stay the same', () => {
  const reply = localizedReply({ version: 1, id: 'a', conversationId: 'c', text: 'Zal ik dit gesprek verwijderen?', blocks: [], usedData: [], question: { text: '', choices: [{ id: 'yes', label: 'Ja' }, { id: 'no', label: 'Nee' }] } }, 'pap')
  assert.equal(reply.text, 'Mi mester kita e kombersashon aki?')
  assert.deepEqual(reply.question?.choices, [{ id: 'yes', label: 'Si' }, { id: 'no', label: 'Nò' }])
})

test('yes and no are heard in every language of the app', () => {
  assert.ok(saysYes('Yes'))
  assert.ok(saysYes('Si'))
  assert.ok(saysNo('No'))
  assert.ok(saysNo('Nò'))
  assert.ok(!saysYes('Nò'))
  assert.equal(withoutConsentAsk('I can compare it. May I look in your vault?'), 'I can compare it.')
})
