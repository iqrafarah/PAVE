// The logo for a vacancy card that came without one: see lookup.ts. Runs with the user's own session and needs
// two-step verification, like the other Ayla functions. Found logos are kept while this function runs.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { CORS, json, sessionLevel } from '../_shared/http.ts'
import { type CompanyLogo, companyLogo, lookupProblem, webSiteSearch } from './lookup.ts'

const known = new Map<string, CompanyLogo | null>()
const MAX_KNOWN = 500

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
  const problem = lookupProblem(body?.company, body?.city)
  if (problem) return json({ error: problem }, 400)
  const company = (body.company as string).trim()
  const city = typeof body.city === 'string' && body.city.trim() ? body.city.trim() : undefined

  const key = `${company}|${city ?? ''}`.toLocaleLowerCase('nl')
  if (!known.has(key)) {
    const found = await companyLogo(company, city, webSiteSearch(openRouterKey)).catch(() => undefined)
    if (known.size >= MAX_KNOWN) known.clear()
    known.set(key, found ?? null)
  }
  const found = known.get(key)
  return json(found ? { logoUrl: found.url, site: found.site } : {})
})
