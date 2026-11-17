// "Laat Ayla invullen": Ayla reads the documents and proposes the whole evidence item. See evidence.ts and logo.ts.
// Requires two-step verification, like Ayla herself.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { HEDGE_MS, MODELS, openRouterCompletion } from '../ayla/openrouter.ts'
import { parseModelJson } from '../ayla-skills/skills.ts'
import { CORS, json, sessionLevel } from '../_shared/http.ts'
import { cleanEvidence, EVIDENCE_SCHEMA, evidenceMessages, parseEvidenceRequest } from './evidence.ts'
import { findLogo } from './logo.ts'

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

  const request = parseEvidenceRequest(await req.json().catch(() => null))
  if (typeof request === 'string') return json({ error: 'invalid_request', detail: request }, 400)

  try {
    // Up to three items with their skills, sources and boxes: far more than a chat reply, so more room and time.
    const complete = openRouterCompletion(openRouterKey, EVIDENCE_SCHEMA, fetch, MODELS, HEDGE_MS, { maxTokens: 3000, timeoutMs: 50_000 })
    const { model, content } = await complete(evidenceMessages(request))
    const parsed = parseModelJson(content)
    const items = cleanEvidence(parsed, request)
    if (!items.length) console.error(`ayla-evidence: ${model} gave nothing usable (${content.length} characters, ends with: ${content.slice(-120)})`)
    // The website's logo is sharper than one cut from a scan, so it is looked up unless a document is only the logo.
    await Promise.all(items.map(async (item) => {
      if ((item.logoDocument !== undefined && !item.logoBox) || !item.website) return
      const logo = await findLogo(item.website)
      if (logo) item.logo = logo
    }))
    return json({ items })
  } catch (error) {
    console.error('ayla-evidence: the models did not answer', error)
    return json({ error: 'unavailable' }, 502)
  }
})
