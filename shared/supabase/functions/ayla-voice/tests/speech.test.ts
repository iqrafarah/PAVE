import assert from 'node:assert/strict'
import { test } from 'node:test'
import { forSpeaking, isSilent, speechAudio, voiceMessages } from '../speech.ts'

// 0.1 s of pcm16 at 24 kHz, loud or silent, as base64 like the voice model sends it.
function chunk(loud: boolean): string {
  const samples = new Int16Array(2400).fill(loud ? 4000 : 0)
  return Buffer.from(samples.buffer).toString('base64')
}

function event(audio: { data?: string; transcript?: string }): string {
  return `data: ${JSON.stringify({ choices: [{ delta: { audio } }] })}\n\n`
}

async function* events(parts: string[]) {
  for (const part of parts) yield part
}

async function collect(parts: string[], text: string) {
  const reasons: string[] = []
  let bytes = 0
  for await (const piece of speechAudio(events(parts), text, (reason) => reasons.push(reason))) bytes += piece.length
  return { seconds: bytes / 48000, reason: reasons[0] }
}

test('PAVE is spelled so the voice says it like the English word', () => {
  assert.equal(forSpeaking('Welkom bij PAVE en pavé.'), 'Welkom bij Peiv en Peiv.')
  assert.equal(forSpeaking('paveren'), 'paveren')
  assert.match(voiceMessages('Hoi')[1].content, /\[BEGIN TEKST\]\nHoi\n\[EINDE TEKST\]/)
})

test('silence is recognised in pcm16', () => {
  assert.equal(isSilent(new Uint8Array(new Int16Array([0, 50, -120]).buffer)), true)
  assert.equal(isSilent(new Uint8Array(new Int16Array([0, 5000]).buffer)), false)
})

test('the whole answer is passed on, also when a line arrives in two pieces', async () => {
  const one = event({ transcript: 'Hoi Daaf', data: chunk(true) })
  const result = await collect([one.slice(0, 20), one.slice(20), event({ data: chunk(true) }), 'data: [DONE]\n'], 'Hoi Daaf')
  assert.equal(result.seconds, 0.2)
  assert.equal(result.reason, 'done')
})

test('the audio stops at the silence after the last word', async () => {
  const parts = [event({ transcript: 'Hoi Daaf', data: chunk(true) }), ...Array.from({ length: 20 }, () => event({ data: chunk(false) }))]
  const result = await collect(parts, 'Hoi Daaf')
  assert.equal(result.reason, 'silence after the text')
  assert.ok(result.seconds < 1)
})

test('when the voice keeps talking after the text it stops at the next pause', async () => {
  const parts = [
    event({ transcript: 'Hoi Daaf. ', data: chunk(true) }),
    event({ transcript: 'Wat wil jij vandaag eigenlijk allemaal gaan doen?', data: chunk(true) }),
    event({ data: chunk(true) }),
    event({ data: chunk(false) }),
    event({ data: chunk(false) }),
    event({ data: chunk(true) }),
  ]
  const result = await collect(parts, 'Hoi Daaf.')
  assert.equal(result.reason, 'extra words')
  assert.ok(result.seconds <= 0.5)
})

test('an error from the voice model is not swallowed', async () => {
  await assert.rejects(collect([`data: ${JSON.stringify({ error: { message: 'no credits' } })}\n`], 'Hoi'), /no credits/)
})
