// Ayla's brain: one endpoint for web, iPhone and Watch. See docs/ayla.md.
// It runs with the user's own session, so row level security applies to every query.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { answer, CONSENT_HISTORY_LIMIT, type StoredMessage, titleFrom, toPastMessage } from './brain.ts'
import { loadMemory } from './memory.ts'
import { loadAllowedVault } from './vault.ts'
import { type AylaReply, parseRequest } from './contract.ts'
import { openRouterCompletion } from './openrouter.ts'
import { MODEL_OUTPUT_SCHEMA } from './prompt.ts'
import { adzunaSearch } from './vacancies.ts'
import { CORS, json, sessionLevel } from '../_shared/http.ts'

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

  const request = parseRequest(await req.json().catch(() => null))
  if (typeof request === 'string') return json({ error: 'invalid_request', detail: request }, 400)

  let conversationId = request.conversationId
  if (conversationId) {
    const { data } = await supabase.from('ayla_conversations').select('id').eq('id', conversationId).maybeSingle()
    if (!data) return json({ error: 'conversation_not_found' }, 404)
  } else {
    const { data, error } = await supabase
      .from('ayla_conversations')
      .insert({ started_on: request.device, title: titleFrom(request.text) })
      .select('id')
      .single()
    if (error || !data) return json({ error: 'unavailable' }, 500)
    conversationId = data.id as string
  }

  const [{ data: past }, { data: profile }, memory, vault] = await Promise.all([
    // More than the model gets, so a Ja to the vault early in a long conversation still counts.
    supabase
      .from('ayla_messages')
      .select('role, text, reply')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: false })
      .limit(CONSENT_HISTORY_LIMIT),
    supabase.from('profiles').select('preferred_name, full_name').eq('id', user.id).maybeSingle(),
    loadMemory(supabase),
    loadAllowedVault(supabase),
  ])
  const history = ((past ?? []) as StoredMessage[]).reverse().map(toPastMessage)
  const firstName = (profile?.preferred_name || profile?.full_name?.split(' ')[0] || undefined) as string | undefined

  const adzunaId = Deno.env.get('ADZUNA_APP_ID')
  const adzunaKey = Deno.env.get('ADZUNA_APP_KEY')

  let title: string | undefined
  const input = { request, conversationId, history, firstName, memory, vault, onTitle: request.conversationId ? undefined : (t: string) => { title = t } }
  const deps = {
    complete: openRouterCompletion(openRouterKey, MODEL_OUTPUT_SCHEMA),
    searchVacancies: adzunaId && adzunaKey ? adzunaSearch(adzunaId, adzunaKey) : undefined,
    newId: () => crypto.randomUUID(),
  }

  /** Stores the question and the answer together, and touches the conversation. */
  const save = async (reply: AylaReply) => {
    const { error } = await supabase.from('ayla_messages').insert([
      { conversation_id: conversationId, role: 'user', text: request.text, device: request.device },
      { conversation_id: conversationId, role: 'ayla', text: reply.text, device: request.device, reply },
    ])
    if (error) return false
    await supabase
      .from('ayla_conversations')
      .update({ updated_at: new Date().toISOString(), ...(title ? { title } : {}) })
      .eq('id', conversationId)
    return true
  }

  // The app asks to see the answer while it is written: server-sent events with the conversation first, then the
  // text so far, then the whole reply. Stopping keeps what was written, as in ChatGPT.
  if ((req.headers.get('Accept') ?? '').includes('text/event-stream')) {
    const stop = new AbortController()
    req.signal.addEventListener('abort', () => stop.abort())
    let written = ''
    const encoder = new TextEncoder()
    const body = new ReadableStream({
      async start(controller) {
        const send = (event: string, data: unknown) => {
          try {
            controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`))
          } catch {
            // The app is gone; the answer is still saved below.
          }
        }
        send('start', { conversationId })
        try {
          const reply = await answer({ ...input, signal: stop.signal, onText: (text) => { written = text; send('text', { text }) } }, deps)
          if (await save(reply)) send('reply', reply)
          else send('error', { error: 'unavailable' })
        } catch {
          if (stop.signal.aborted && written) {
            await save({ version: 1, id: crypto.randomUUID(), conversationId: conversationId!, text: written, blocks: [], usedData: [] })
          } else {
            send('error', { error: 'unavailable' })
          }
        }
        try {
          controller.close()
        } catch {
          // Already closed by the app.
        }
      },
      cancel() {
        stop.abort()
      },
    })
    return new Response(body, { headers: { ...CORS, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' } })
  }

  let reply: AylaReply
  try {
    reply = await answer(input, deps)
  } catch {
    return json({ error: 'unavailable' }, 502)
  }
  if (!await save(reply)) return json({ error: 'unavailable' }, 500)

  return json(reply)
})
