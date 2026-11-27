// Public on purpose (verify_jwt = false): the recruiter in the demo has no PAVE account. Everything behind the
// employer's secret key; see inbox.ts.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { CORS, json } from '../_shared/http.ts'
import { type ApplicationRow, inboxView, parseInboxRequest, photoPath, sameHash, sha256 } from './inbox.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  const request = parseInboxRequest(await req.json().catch(() => null), new Date())
  if ('error' in request) return json({ error: request.error }, 400)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
  const { data: keyRow } = await admin.from('fair_employer_keys').select('key_hash').eq('employer_slug', request.slug).maybeSingle()
  if (!keyRow || !sameHash(await sha256(request.key), keyRow.key_hash)) return json({ error: 'not_allowed' }, 403)

  if (request.action === 'invite') {
    const { data, error } = await admin.from('fair_applications')
      .update({ status: 'invited', invited_at: new Date().toISOString(), invited_for: request.moment, invitation_message: request.message ?? null, answer: null, answered_at: null })
      .eq('id', request.applicationID!).eq('employer_slug', request.slug).select('id')
    if (error) return json({ error: 'unavailable' }, 500)
    if (!data?.length) return json({ error: 'not_found' }, 404)
  }

  const { data: employer } = await admin.from('fair_employers').select('slug,name,stand').eq('slug', request.slug).maybeSingle()
  const { data: rows, error } = await admin.from('fair_applications')
    .select('id,user_id,employer_slug,vacancy_id,vacancy_title,card,status,invited_for,invitation_message,answer,created_at')
    .eq('employer_slug', request.slug).order('created_at', { ascending: false }).limit(100)
  if (error) return json({ error: 'unavailable' }, 500)
  // The photos of applicants who chose to show theirs, as links that work for a few minutes.
  const applications = rows as ApplicationRow[]
  const withPhoto = applications.filter((row) => row.card?.showsPhoto === true && row.user_id).map((row) => row.user_id as string)
  const photos = new Map<string, string>()
  if (withPhoto.length > 0) {
    const { data: owners } = await admin.from('profiles').select('id,avatar_path').in('id', [...new Set(withPhoto)])
    const paths = new Map((owners ?? []).map((owner: { id: string; avatar_path: string | null }) => [owner.id, owner.avatar_path]))
    for (const row of applications) {
      const path = photoPath(row, paths.get(row.user_id ?? ''))
      if (!path) continue
      const { data: link } = await admin.storage.from('pave-avatars').createSignedUrl(path, 300)
      if (link?.signedUrl) photos.set(row.id, link.signedUrl)
    }
  }
  return json({ employer, applications: applications.map((row) => inboxView(row, photos.get(row.id))) })
})
