import { assertEquals } from 'jsr:@std/assert@1'
import { cleanWriting, documentAnswer, documentMessages, parseDocumentRequest } from '../document.ts'

const vacancy = { title: 'Junior iOS-ontwikkelaar', company: 'Appwerk', matches: ['Swift'], skillGap: ['CI/CD'] }
const items = [
  { id: 'a', title: 'Eindstage front-end', category: 'internships', organisation: 'Pixelwerk', skills: ['Swift'] },
  { id: 'b', title: 'HBO-ICT', category: 'diplomas', skills: [] },
]

Deno.test('a request needs a kind, a vacancy and items with an id and title', () => {
  assertEquals(typeof parseDocumentRequest({ kind: 'letter', vacancy, name: 'Daaf', items }), 'object')
  assertEquals(parseDocumentRequest({ kind: 'poem', vacancy, items }), 'kind')
  assertEquals(parseDocumentRequest({ kind: 'letter', vacancy: { title: 'x' }, items }), 'vacancy')
  assertEquals(parseDocumentRequest({ kind: 'letter', vacancy, items: [{ title: 'zonder id' }] }), 'items')
  assertEquals(parseDocumentRequest({ kind: 'rewrite', vacancy, items, text: 'Hoi', rewrite: 'louder' }), 'rewrite')
})

Deno.test('the evidence is numbered and what is missing is never claimed', () => {
  const request = parseDocumentRequest({ kind: 'letter', vacancy, name: 'Daaf', items })
  if (typeof request === 'string') throw new Error(request)
  const prompt = documentMessages(request)[1].content
  assertEquals(prompt.includes('1. (internships) Eindstage front-end, Pixelwerk.'), true)
  assertEquals(prompt.includes('Noem dit niet als iets wat de gebruiker kan'), true)
})

Deno.test('sources only point at evidence that was sent', () => {
  const request = parseDocumentRequest({ kind: 'letter', vacancy, name: 'Daaf', items })
  if (typeof request === 'string') throw new Error(request)
  const answer = documentAnswer({
    salutation: 'Beste team van Appwerk,', closing: 'Met vriendelijke groet,',
    paragraphs: [{ text: 'Bij Pixelwerk werkte ik met Swift.', sources: [1, 7] }, { text: ' ', sources: [] }],
  }, request)
  assertEquals(answer.paragraphs, [{ text: 'Bij Pixelwerk werkte ik met Swift.', sourceItemIDs: ['a'] }])
  assertEquals(answer.profile, undefined)
})

Deno.test('dashes and quotes are cleaned out of what she writes', () => {
  assertEquals(cleanWriting('"Ik bouw apps — graag met Swift."'), 'Ik bouw apps, graag met Swift.')
  assertEquals(cleanWriting('   '), undefined)
})

Deno.test('she says nothing about the company or the job that is not in the data, and a rewrite adds nothing', () => {
  const letter = parseDocumentRequest({ kind: 'letter', vacancy, name: 'Daaf', items })
  const rewrite = parseDocumentRequest({ kind: 'rewrite', vacancy, name: 'Daaf', items, text: 'Ik bouw apps.', rewrite: 'shorter' })
  if (typeof letter === 'string' || typeof rewrite === 'string') throw new Error('request')
  assertEquals(documentMessages(letter)[0].content.includes('Zeg niets over het bedrijf wat niet in de vacature staat'), true)
  assertEquals(documentMessages(letter)[0].content.includes('schrijf nooit alsof hij of zij de functie al heeft'), true)
  assertEquals(documentMessages(rewrite)[1].content.includes('Voeg niets toe wat niet al in de tekst staat'), true)
})

Deno.test('the line under the name comes with the profile, without a full stop', () => {
  const request = parseDocumentRequest({ kind: 'profile', vacancy, name: 'Daaf', items })
  if (typeof request === 'string') throw new Error(request)
  assertEquals(documentMessages(request)[1].content.includes('Nooit de functie uit de vacature'), true)
  const answer = documentAnswer({ profile: 'Ik bouw apps.', headline: 'Student HBO-ICT.' }, request)
  assertEquals(answer.headline, 'Student HBO-ICT')
  assertEquals(answer.profile, 'Ik bouw apps.')
})

Deno.test('what was done at a job is only rewritten from its own description', () => {
  const described = [{ ...items[0], description: 'Je bouwde mee aan een iOS-app.' }, items[1]]
  const request = parseDocumentRequest({ kind: 'entries', vacancy, name: 'Daaf', items: described })
  if (typeof request === 'string') throw new Error(request)
  assertEquals(documentMessages(request)[1].content.includes('zonder "ik" of "je" als onderwerp'), true)
  const answer = documentAnswer({
    entries: [
      { source: 1, text: 'Bouwde mee aan een iOS-app.' },
      { source: 1, text: 'Nog een keer.' },
      { source: 2, text: 'Verzonnen bij een diploma zonder beschrijving.' },
      { source: 9, text: 'Bestaat niet.' },
    ],
  }, request)
  assertEquals(answer.entries, [{ sourceItemID: 'a', text: 'Bouwde mee aan een iOS-app.' }])
  assertEquals(answer.profile, undefined)
})

Deno.test('what the user wants stressed goes along as a wish, never as a fact', () => {
  const letter = parseDocumentRequest({ kind: 'letter', vacancy, name: 'Daaf', items, focus: '  Samenwerken met "klanten"  ' })
  const entries = parseDocumentRequest({ kind: 'entries', vacancy, name: 'Daaf', items, focus: 'Samenwerken' })
  if (typeof letter === 'string' || typeof entries === 'string') throw new Error('request')
  const prompt = documentMessages(letter)[1].content
  assertEquals(prompt.includes(`De gebruiker wil de nadruk leggen op: "Samenwerken met 'klanten'".`), true)
  assertEquals(prompt.includes('Staat het niet in de bewijsstukken, noem het dan niet'), true)
  assertEquals(entries.focus, undefined)
  assertEquals(documentMessages(entries)[1].content.includes('nadruk'), false)
})
