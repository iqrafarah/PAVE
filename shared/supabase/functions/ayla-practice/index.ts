// The report after a practice interview. See report.ts. Requires two-step verification like Ayla herself.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { HEDGE_MS, MODELS, openRouterCompletion } from '../ayla/openrouter.ts'
import { CORS, json, sessionLevel } from '../_shared/http.ts'
import { parseModelJson } from '../ayla-skills/skills.ts'
import { cleanReport, parsePracticeRequest, practiceMessages, REPORT_SCHEMA } from './report.ts'

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

  const request = parsePracticeRequest(await req.json().catch(() => null))
  if (typeof request === 'string') return json({ error: 'invalid_request', detail: request }, 400)

  try {
    const complete = openRouterCompletion(openRouterKey, REPORT_SCHEMA, fetch, MODELS, HEDGE_MS, { maxTokens: 1400, timeoutMs: 40_000 })
    const { model, content } = await complete(practiceMessages(request))
    const parsed = parseModelJson(content)
    if (!parsed) console.error(`ayla-practice: ${model} gave no usable JSON`)
    const report = cleanReport(parsed)
    if (!report) return json({ error: 'unavailable' }, 502)
    return json(report)
  } catch (error) {
    console.error('ayla-practice: the models did not answer', error)
    return json({ error: 'unavailable' }, 502)
  }
})
