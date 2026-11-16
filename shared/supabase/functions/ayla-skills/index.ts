// "Voorstel van Ayla" for skills when adding evidence. See skills.ts. Requires two-step verification like Ayla herself.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { openRouterCompletion } from '../ayla/openrouter.ts'
import { CORS, json, sessionLevel } from '../_shared/http.ts'
import { cleanSkills, parseModelJson, parseSkillsRequest, SKILLS_SCHEMA, skillsMessages } from './skills.ts'

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

  const request = parseSkillsRequest(await req.json().catch(() => null))
  if (typeof request === 'string') return json({ error: 'invalid_request', detail: request }, 400)

  try {
    const { model, content } = await openRouterCompletion(openRouterKey, SKILLS_SCHEMA)(skillsMessages(request))
    const parsed = parseModelJson(content)
    if (!parsed) console.error(`ayla-skills: ${model} gave no usable JSON`)
    return json({ skills: cleanSkills(parsed, request.existing) })
  } catch (error) {
    console.error('ayla-skills: the models did not answer', error)
    return json({ error: 'unavailable' }, 502)
  }
})
