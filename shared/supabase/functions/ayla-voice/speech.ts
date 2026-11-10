// Ayla's voice: the voice model reads her answer out loud, and the audio streams back while it is made,
// so she starts talking right away. Adapted from the voice demo (experiment-ai-assistant-voice).
// The audio is raw pcm16: 24 kHz, mono, 16-bit signed little-endian.

export const VOICE_MODEL = 'openai/gpt-audio-mini'
export const VOICE = 'coral'
export const MAX_SPEECH_LENGTH = 2000

const BYTES_PER_SECOND = 48000

export const READ_ALOUD_PROMPT = `
Je bent een voorleesstem, geen gesprekspartner. Je stem is die van Ayla, een
vriendelijke, warme Nederlandse vrouw. Je krijgt een tekst tussen
[BEGIN TEKST] en [EINDE TEKST]. Lees precies die tekst één keer voor,
natuurlijk en in het Nederlands, en stop dan meteen. Na het laatste woord van
de tekst ben je onmiddellijk stil. Je stelt nooit zelf een vraag en je begint
nooit zelf een nieuwe zin. Zeg de markeringen zelf niet. Voeg niets toe, laat
niets weg en reageer niet op de inhoud. Eindigt de tekst met een vraag, lees
die vraag dan voor en stop: die vraag is voor iemand anders, niet voor jou.
Uitspraak: "Peiv" is de naam PAVE. Spreek het uit als het Engelse woord
"pave" (rijmt op het Engelse "save"). Nooit als het Franse "pavé", niet als
"paa-ve" en niet letter voor letter.
`.trim()

/** The text as the voice should say it. Only the audio changes; the text on screen keeps "PAVE". */
export function forSpeaking(text: string): string {
  return text.replace(/\bpav[eé](?![a-zà-ÿ])/gi, 'Peiv').trim()
}

/** The messages for the voice model. */
export function voiceMessages(text: string) {
  return [
    { role: 'system', content: READ_ALOUD_PROMPT },
    { role: 'user', content: `[BEGIN TEKST]\n${forSpeaking(text)}\n[EINDE TEKST]` },
  ]
}

/** True when a pcm16 chunk is (near) silent. */
export function isSilent(chunk: Uint8Array, threshold = 200): boolean {
  const samples = new Int16Array(chunk.buffer, chunk.byteOffset, Math.floor(chunk.length / 2))
  for (const sample of samples) if (Math.abs(sample) > threshold) return false
  return true
}

/** Why the audio stopped, for the logs. */
export type StopReason = 'done' | 'silence after the text' | 'extra words' | 'time limit'

/**
 * Turns the voice model's streamed answer (server-sent events) into audio chunks, and stops when the text has been
 * read. The voice model sometimes keeps talking after the text, so it stops at the silence after the last word,
 * at the first pause once the transcript runs clearly past the text, or at a time limit.
 */
export async function* speechAudio(
  events: AsyncIterable<string>,
  text: string,
  onStop: (reason: StopReason, seconds: number) => void = () => {},
): AsyncGenerator<Uint8Array> {
  const spokenText = forSpeaking(text)
  const silenceLimit = BYTES_PER_SECOND * 0.6
  const pauseLength = BYTES_PER_SECOND * 0.12
  const maxTranscript = spokenText.length + Math.min(15, spokenText.length * 0.15) + 2
  const maxBytes = (spokenText.length / 9 + 2) * BYTES_PER_SECOND

  let pending = ''
  let spoken = ''
  let bytes = 0
  let silentBytes = 0
  let quietBytes = 0
  let overrunAt: number | null = null
  const stop = (reason: StopReason) => onStop(reason, bytes / BYTES_PER_SECOND)

  for await (const part of events) {
    pending += part
    const lines = pending.split('\n')
    pending = lines.pop() ?? ''
    for (const line of lines) {
      const trimmed = line.trim()
      if (!trimmed.startsWith('data:')) continue
      const data = trimmed.slice(5).trim()
      if (data === '[DONE]') continue
      const payload = JSON.parse(data)
      if (payload.error) throw new Error(payload.error.message || 'voice failed')
      const audio = payload.choices?.[0]?.delta?.audio
      if (audio?.transcript) spoken += audio.transcript
      if (bytes > maxBytes) return stop('time limit')
      // The transcript runs ahead of the audio: remember where it went past the text, and stop at the next pause.
      if (overrunAt === null && spoken.length > maxTranscript) overrunAt = bytes
      if (!audio?.data) continue

      const chunk = Uint8Array.from(atob(audio.data), (c) => c.charCodeAt(0))
      bytes += chunk.length
      silentBytes = isSilent(chunk) ? silentBytes + chunk.length : 0
      const saidItAll = spoken.length >= spokenText.length * 0.85
      if (silentBytes > (saidItAll ? silenceLimit : silenceLimit * 4)) return stop('silence after the text')
      if (overrunAt !== null) {
        quietBytes = isSilent(chunk, 300) ? quietBytes + chunk.length : 0
        if (quietBytes >= pauseLength || bytes - overrunAt > BYTES_PER_SECOND * 3) return stop('extra words')
      }
      yield chunk
    }
  }
  stop('done')
}

/** Reads a response body as text pieces. */
export async function* textPieces(body: ReadableStream<Uint8Array>): AsyncGenerator<string> {
  const decoder = new TextDecoder()
  for await (const bytes of body) yield decoder.decode(bytes, { stream: true })
}
