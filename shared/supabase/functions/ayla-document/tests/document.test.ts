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
