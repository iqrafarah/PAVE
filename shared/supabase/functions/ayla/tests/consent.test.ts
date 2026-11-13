import assert from 'node:assert/strict'
import { test } from 'node:test'
import { cleanPurpose, vaultConsent } from '../consent.ts'

const asked = { role: 'ayla' as const, text: 'Mag ik in je kluis kijken om je diploma te zoeken?', askedVault: true }
const user = (text: string) => ({ role: 'user' as const, text })
const ayla = (text: string) => ({ role: 'ayla' as const, text })

test('without a question for the vault Ayla has not asked yet', () => {
  assert.equal(vaultConsent([], { text: 'Zoek mijn diploma' }), 'notAsked')
  assert.equal(vaultConsent([user('Hoi'), ayla('Hoi!')], { text: 'Ja' }), 'notAsked')
})

test('a Ja right after her question lets her look now, and for the rest of the conversation', () => {
  assert.equal(vaultConsent([user('Zoek mijn diploma'), asked], { text: 'Ja' }), 'justGranted')
  assert.equal(vaultConsent([user('Zoek mijn diploma'), asked], { text: 'Ja, graag' }), 'justGranted')
  const later = [user('Zoek mijn diploma'), asked, user('Ja'), ayla('Gevonden.'), user('Dank je'), ayla('Graag gedaan.')]
  assert.equal(vaultConsent(later, { text: 'En mijn stage?' }), 'granted')
})

test('a Nee keeps the vault closed, and something else is no answer', () => {
  assert.equal(vaultConsent([user('Zoek mijn diploma'), asked], { text: 'Nee' }), 'declined')
  assert.equal(vaultConsent([user('Zoek mijn diploma'), asked], { text: 'Liever niet' }), 'declined')
  assert.equal(vaultConsent([user('Zoek mijn diploma'), asked], { text: 'Wat bedoel je?' }), 'notAsked')
})

test('the latest answer counts, and asking about one item is consent', () => {
  const history = [user('Zoek mijn diploma'), asked, user('Ja'), ayla('Gevonden.'), user('Kijk nog eens'), asked]
  assert.equal(vaultConsent(history, { text: 'Nee' }), 'declined')
  assert.equal(vaultConsent([], { text: 'Wat laat dit zien?', context: { screen: 'vaultItem', itemId: 'x' } }), 'granted')
})

test('the purpose fits "Mag ik in je kluis kijken om …?"', () => {
  assert.equal(cleanPurpose('Om je diploma te zoeken?'), 'je diploma te zoeken')
  assert.equal(cleanPurpose('  te zien welke vaardigheden je hebt. '), 'te zien welke vaardigheden je hebt')
  assert.equal(cleanPurpose(''), null)
  assert.equal(cleanPurpose(null), null)
  assert.ok((cleanPurpose('x '.repeat(200)) ?? '').length <= 140)
})
