import assert from 'node:assert/strict'
import { test } from 'node:test'
import { audioProblem, cleanTranscript, listenMessages, MAX_AUDIO_BYTES, MAX_TRANSCRIPT_LENGTH, toBase64 } from '../listen.ts'

test('only a WAV recording of a sensible size goes on', () => {
  assert.equal(audioProblem('audio/wav', 32000), null)
  assert.equal(audioProblem('audio/x-wav; charset=binary', 32000), null)
  assert.equal(audioProblem('audio/mpeg', 32000), 'unsupported_media_type')
  assert.equal(audioProblem(null, 32000), 'unsupported_media_type')
  assert.equal(audioProblem('audio/wav', 0), 'invalid_request')
  assert.equal(audioProblem('audio/wav', MAX_AUDIO_BYTES + 1), 'invalid_request')
})

test('the model gets the instruction and the recording, nothing else', () => {
  const messages = listenMessages('UklGRg==')
  assert.equal(messages.length, 2)
  assert.match(messages[0].content as string, /Beantwoord geen vragen/)
  const parts = messages[1].content as { type: string; input_audio?: { data: string; format: string } }[]
  assert.deepEqual(parts[1], { type: 'input_audio', input_audio: { data: 'UklGRg==', format: 'wav' } })
})

test('the transcript is one clean line', () => {
  assert.equal(cleanTranscript('  "Welke stage\n past bij mij?"  '), 'Welke stage past bij mij?')
  assert.equal(cleanTranscript('“Zet mijn stage in de kluis.”'), 'Zet mijn stage in de kluis.')
  assert.equal(cleanTranscript('[stilte]'), '')
  assert.equal(cleanTranscript(''), '')
  assert.equal(cleanTranscript(undefined), '')
  assert.equal(cleanTranscript('a'.repeat(MAX_TRANSCRIPT_LENGTH + 10)).length, MAX_TRANSCRIPT_LENGTH)
})

test('base64 also works for recordings larger than one chunk', () => {
  const bytes = new Uint8Array(70000).map((_, i) => i % 256)
  assert.equal(toBase64(bytes), Buffer.from(bytes).toString('base64'))
})
