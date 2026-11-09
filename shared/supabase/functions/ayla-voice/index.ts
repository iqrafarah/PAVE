// Ayla's voice: reads one of her answers out loud and streams the audio (pcm16, 24 kHz, mono).
// Only the text of Ayla's answer is sent to the voice model; the user's own voice never leaves the device.
// It runs with the user's own session and needs two-step verification, like the `ayla` function.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { CORS, json, sessionLevel } from '../_shared/http.ts'
import { MAX_SPEECH_LENGTH, speechAudio, textPieces, VOICE, VOICE_MODEL, voiceMessages } from './speech.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  const openRouterKey = Deno.env.get('OPENROUTER_API_KEY')
  if (!openRouterKey) return json({ error: 'not_configured' }, 500)

  const authorization = req.headers.get('Authorization') ?? ''
  const token = authorization.replace(/^Bearer\s+/i, '')
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
  })
  const { data: { user } } = await supabase.auth.getUser(token)
  if (!user) return json({ error: 'not_signed_in' }, 401)
  if (sessionLevel(token) !== 'aal2') return json({ error: 'insufficient_aal' }, 403)

  const body = await req.json().catch(() => null)
  const text = typeof body?.text === 'string' ? body.text.trim() : ''
  if (!text || text.length > MAX_SPEECH_LENGTH) return json({ error: 'invalid_request' }, 400)

  const upstream = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    signal: AbortSignal.timeout(30000),
    headers: { Authorization: `Bearer ${openRouterKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: VOICE_MODEL,
      temperature: 0,
      messages: voiceMessages(text),
      stream: true,
      modalities: ['text', 'audio'],
      audio: { voice: VOICE, format: 'pcm16' },
    }),
  }).catch(() => null)
  if (!upstream?.ok || !upstream.body) return json({ error: 'unavailable' }, 502)

  const chunks = speechAudio(textPieces(upstream.body), text, (reason, seconds) => {
    console.log(`[ayla-voice] stopped (${reason}) after ${seconds.toFixed(1)} s of audio`)
  })
  const audio = new ReadableStream<Uint8Array>({
    async pull(controller) {
      try {
        const next = await chunks.next()
        if (next.done) controller.close()
        else controller.enqueue(next.value)
      } catch {
        controller.close()
      }
    },
    async cancel() {
      await chunks.return(undefined)
      await upstream.body?.cancel().catch(() => {})
    },
  })
  return new Response(audio, {
    headers: { ...CORS, 'Content-Type': 'application/octet-stream', 'Cache-Control': 'no-store' },
  })
})
