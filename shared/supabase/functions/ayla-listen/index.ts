// Ayla's ears for the Apple Watch: turns a short recording into text, which the Watch then sends to `ayla`.
// It runs with the user's own session and needs two-step verification, like `ayla` and `ayla-voice`.
// The recording is not stored or logged.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { CORS, json, sessionLevel } from '../_shared/http.ts'
import { audioProblem, cleanTranscript, LISTEN_MODEL, listenMessages, toBase64 } from './listen.ts'

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

  const audio = new Uint8Array(await req.arrayBuffer().catch(() => new ArrayBuffer(0)))
  const problem = audioProblem(req.headers.get('Content-Type'), audio.byteLength)
  if (problem) return json({ error: problem }, problem === 'unsupported_media_type' ? 415 : 400)

  const upstream = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    signal: AbortSignal.timeout(30000),
    headers: { Authorization: `Bearer ${openRouterKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: LISTEN_MODEL,
      temperature: 0,
      modalities: ['text'],
      messages: listenMessages(toBase64(audio)),
    }),
  }).catch(() => null)
  if (!upstream?.ok) return json({ error: 'unavailable' }, 502)

  const result = await upstream.json().catch(() => null)
  return json({ text: cleanTranscript(result?.choices?.[0]?.message?.content) })
})
