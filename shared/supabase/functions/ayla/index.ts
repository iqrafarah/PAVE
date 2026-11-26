// Ayla's brain: one endpoint for web, iPhone and Watch. See docs/ayla.md.
// It runs with the user's own session, so row level security applies to every query.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { answer, CONSENT_HISTORY_LIMIT, type StoredMessage, titleFrom, toPastMessage } from './brain.ts'
import { loadMemory } from './memory.ts'
import { loadAllowedVault } from './vault.ts'
import { loadPlan, planExists, stepUpdater } from './plan.ts'
import { type AylaReply, parseRequest } from './contract.ts'
import { openRouterCompletion } from './openrouter.ts'
import { MODEL_OUTPUT_SCHEMA } from './prompt.ts'
import { adzunaSearch, firstThatFinds, joobleSearch, type SearchVacancies, siteChecker, webSearch, withSupport } from './vacancies.ts'
import { CORS, json, sessionLevel } from '../_shared/http.ts'

/**
 * The project's name, instructions and the vault items the user added as sources (ids; which of them Ayla may see is
 * up to vault.ts). Before the projects migration runs the query fails and there is none; before the sources migration
 * there are no sources.
 */
async function loadProject(supabase: ReturnType<typeof createClient>, conversationId: string) {
  const { data, error } = await supabase
    .from('ayla_conversations')
    .select('project_id, ayla_projects(name, instructions)')
    .eq('id', conversationId)
    .maybeSingle()
  const row = error ? null : (data as { project_id: string | null; ayla_projects: { name: string; instructions: string } | null } | null)
  if (!row?.ayla_projects) return undefined
  const { data: sources, error: sourcesError } = await supabase.from('ayla_project_sources').select('item_id').eq('project_id', row.project_id)
  const sourceIds = sourcesError ? [] : ((sources ?? []) as { item_id: string }[]).map((source) => source.item_id)
  return { ...row.ayla_projects, sourceIds }
}

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
  if (typeof request === 'string') {
    // Why a question was refused, so a 400 in the logs says what to fix.
    console.warn('ayla: refused request:', request)
    return json({ error: 'invalid_request', detail: request }, 400)
  }

  let conversationId = request.conversationId
  if (conversationId) {
    const { data } = await supabase.from('ayla_conversations').select('id').eq('id', conversationId).maybeSingle()
    if (!data) return json({ error: 'conversation_not_found' }, 404)
  } else {
    if (request.projectId) {
      // Row level security only lets the user see their own projects.
      const { data } = await supabase.from('ayla_projects').select('id').eq('id', request.projectId).maybeSingle()
      if (!data) return json({ error: 'project_not_found' }, 404)
    }
    // A plan that is not there (or before the plans migration) is left out: the chat still starts, without a plan.
    const inPlan = request.planId && await planExists(supabase, request.planId)
    const { data, error } = await supabase
      .from('ayla_conversations')
      .insert({
        started_on: request.device,
        title: titleFrom(request.text),
        ...(request.projectId ? { project_id: request.projectId } : {}),
        ...(inPlan ? { plan_id: request.planId, ...(request.planStepId ? { plan_step_id: request.planStepId } : {}) } : {}),
      })
      .select('id')
      .single()
    if (error || !data) return json({ error: 'unavailable' }, 500)
    conversationId = data.id as string
  }

  const [{ data: past }, { data: profile }, memory, vault, project, plan] = await Promise.all([
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
    loadProject(supabase, conversationId),
    loadPlan(supabase, conversationId),
  ])
  const history = ((past ?? []) as StoredMessage[]).reverse().map(toPastMessage)
  const firstName = (profile?.preferred_name || profile?.full_name?.split(' ')[0] || undefined) as string | undefined

  // Vacancies from the job API that has a key (Adzuna, then Jooble), with the web search beside it: more vacancies,
  // and more of their text. Without a job API the web is the only source.
  const adzunaId = Deno.env.get('ADZUNA_APP_ID')
  const adzunaKey = Deno.env.get('ADZUNA_APP_KEY')
  const joobleKey = Deno.env.get('JOOBLE_API_KEY')
  const apis: SearchVacancies[] = [
    ...(adzunaId && adzunaKey ? [adzunaSearch(adzunaId, adzunaKey)] : []),
    ...(joobleKey ? [joobleSearch(joobleKey, Deno.env.get('JOOBLE_HOST') || undefined)] : []),
  ]

  let title: string | undefined
  const input = { request, conversationId, history, firstName, memory, vault, project, plan, onTitle: request.conversationId ? undefined : (t: string) => { title = t } }
  const deps = {
    complete: openRouterCompletion(openRouterKey, MODEL_OUTPUT_SCHEMA),
    searchVacancies: withSupport(firstThatFinds(apis), webSearch(openRouterKey)),
    newId: () => crypto.randomUUID(),
    siteExists: siteChecker(),
    updatePlanStep: stepUpdater(supabase),
  }

  /** Stores the question and the answer together. */
  const store = async (reply: AylaReply) => {
    // A user message keeps only the names of its files in `reply`, so the chat shows them again; the files' text
    // is never stored.
    const attachments = request.attachments?.length ? { attachments: request.attachments.map((file) => file.name) } : null
    const answer = { conversation_id: conversationId, role: 'ayla', text: reply.text, device: request.device, reply }
    // A turn the app sent itself (what came of Ayla's actions) is not something the user said: only her answer is kept.
    const rows = request.results?.length
      ? [answer]
      : [{ conversation_id: conversationId, role: 'user', text: request.text, device: request.device, reply: attachments }, answer]
    const { error } = await supabase.from('ayla_messages').insert(rows)
    return !error
  }

  /** Moves the conversation to the top of the list, with its title. */
  const touch = async () => {
    await supabase
      .from('ayla_conversations')
      .update({ updated_at: new Date().toISOString(), ...(title ? { title } : {}) })
      .eq('id', conversationId)
  }

  const save = async (reply: AylaReply) => {
    if (!await store(reply)) return false
    await touch()
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
          const reply = await answer({
            ...input,
            signal: stop.signal,
            onText: (text) => { written = text; send('text', { text }) },
            onStatus: (status) => send('status', status),
          }, deps)
          // The answer shows as soon as it is stored; the list of conversations catches up after.
          if (await store(reply)) {
            send('reply', reply)
            await touch()
          } else {
            send('error', { error: 'unavailable' })
          }
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
