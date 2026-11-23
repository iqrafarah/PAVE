// The demo wallet for the vault (Npuls feedback, 2026-11-23): "Uit je wallet" shows the credentials in the account's
// made-up wallet and puts the chosen ones in the vault as confirmed evidence. Only trusted server code may add an item
// that is confirmed or imported (guard_vault_item_authority), so this uses the service key, and only after checking the
// caller and only for the credentials of the caller's own demo wallet. Nothing comes from or goes to a real wallet.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { CORS, json, sessionLevel } from '../_shared/http.ts'
import { itemRow, sameEvidence, walletFor } from './wallet.ts'

const URL = Deno.env.get('SUPABASE_URL')!
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  const authorization = req.headers.get('Authorization') ?? ''
  const token = authorization.replace(/^Bearer\s+/i, '')
  const authClient = createClient(URL, ANON, { global: { headers: { Authorization: authorization } } })
  const { data: { user }, error: authError } = await authClient.auth.getUser(token)
  if (authError || !user) return json({ error: 'not_signed_in' }, 401)
  if (sessionLevel(token) !== 'aal2') return json({ error: 'insufficient_aal' }, 403)

  const body = await req.json().catch(() => null) as { action?: string; ids?: unknown } | null
  if (!body || !['list', 'import'].includes(body.action ?? '')) return json({ error: 'invalid_request' }, 400)

  try {
    const wallet = walletFor(user.id)
    // What is already in the vault, so a credential is not taken twice.
    const { data: imported, error: importedError } = await authClient.from('vault_items')
      .select('title,organisation_name').eq('user_id', user.id).eq('source', 'import')
    if (importedError) throw importedError
    const isImported = (id: string) => {
      const credential = wallet.find((c) => c.id === id)!
      return (imported ?? []).some((item) => sameEvidence(credential, item))
    }

    if (body.action === 'list') {
      return json({ credentials: wallet.map((credential) => ({ ...credential, imported: isImported(credential.id) })) })
    }

    if (!Array.isArray(body.ids) || !body.ids.length || body.ids.length > wallet.length || body.ids.some((id) => typeof id !== 'string')) {
      return json({ error: 'invalid_request' }, 400)
    }
    const chosen = wallet.filter((credential) => (body.ids as string[]).includes(credential.id) && !isImported(credential.id))
    if (!chosen.length) return json({ itemIds: [] })

    const admin = createClient(URL, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } })
    const { data: items, error: insertError } = await admin.from('vault_items')
      .insert(chosen.map((credential) => itemRow(credential, user.id))).select('id,title')
    if (insertError) throw insertError
    const skills = (items ?? []).flatMap((item) => {
      const credential = chosen.find((c) => c.title === item.title)
      return (credential?.skills ?? []).map((name) => ({ user_id: user.id, item_id: item.id, name, source: 'import', status: 'accepted' }))
    })
    if (skills.length) {
      const { error: skillsError } = await admin.from('vault_item_skills').insert(skills)
      if (skillsError) throw skillsError
    }
    return json({ itemIds: (items ?? []).map((item) => item.id) })
  } catch (error) {
    console.error('vault-wallet failed', (error as { code?: string })?.code ?? '')
    return json({ error: 'failed' }, 500)
  }
})
