// Opens a shared profile for whoever has the code (a link or a QR code), without an account: see share.ts. Each look is
// written down for the owner. Paused, taken back or ended shares show nothing but that.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { CORS, json } from '../_shared/http.ts'
import {
  documentPaths, fileItemIDs, parseViewRequest, sharedFiles, shareState, shareView, verifications,
  type FileRow, type FileView, type ItemRow, type ShareRow, type VerificationRow,
} from './share.ts'

const SECONDS_A_FILE_LINK_WORKS = 300

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  const request = parseViewRequest(await req.json().catch(() => null))
  if (typeof request === 'string') return json({ error: 'invalid_request', detail: request }, 400)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
  const { data: share, error } = await admin.from('profile_shares').select('*').eq('code', request.code).maybeSingle<ShareRow>()
  if (error) {
    console.error('share-view: reading the share failed', error.message)
    return json({ error: 'unavailable' }, 502)
  }
  if (!share) return json({ state: 'unknown' }, 404)

  const state = shareState(share, new Date())
  if (state !== 'active') {
    return json({ state, title: share.title, recipient: { name: share.recipient_name, organisation: share.recipient_organisation ?? undefined } })
  }
  if (request.action === 'download' && !share.allows_download) return json({ error: 'download_not_allowed' }, 403)

  const items: ItemRow[] = []
  if (share.item_ids.length > 0) {
    const { data, error: itemsError } = await admin
      .from('vault_items')
      .select('id,user_id,category,title,description,organisation_name,organisation_location,start_date,end_date,issued_on,is_current,verification_status,source,archived_at,vault_item_skills(name,status)')
      .in('id', share.item_ids)
      .eq('user_id', share.user_id)
    if (itemsError) {
      console.error('share-view: reading the evidence failed', itemsError.message)
      return json({ error: 'unavailable' }, 502)
    }
    items.push(...((data ?? []) as ItemRow[]))
  }

  // Who verified the evidence, for every piece in the share; the files only of the pieces the owner let go along.
  const verified = new Map<string, { by: string; on: string }>()
  if (share.item_ids.length > 0) {
    const { data } = await admin
      .from('vault_validation_requests')
      .select('item_id,user_id,organisation_name,status,resolved_at')
      .in('item_id', share.item_ids)
      .eq('user_id', share.user_id)
      .eq('status', 'verified')
    for (const [id, value] of verifications((data ?? []) as VerificationRow[], share.user_id)) verified.set(id, value)
  }
  const files = new Map<string, FileView[]>()
  const withFiles = fileItemIDs(share)
  if (withFiles.length > 0) {
    const { data } = await admin
      .from('vault_item_files')
      .select('id,user_id,item_id,storage_path,file_name,mime_type,role')
      .in('item_id', withFiles)
      .eq('user_id', share.user_id)
    for (const file of sharedFiles(share, (data ?? []) as FileRow[])) {
      const { data: link } = await admin.storage
        .from('pave-vault')
        .createSignedUrl(file.storage_path, SECONDS_A_FILE_LINK_WORKS, share.allows_download ? { download: file.file_name } : undefined)
      if (!link?.signedUrl) continue
      files.set(file.item_id, [...(files.get(file.item_id) ?? []), { name: file.file_name, mimeType: file.mime_type, url: link.signedUrl }])
    }
  }

  const documents: { kind: string; url: string }[] = []
  for (const doc of documentPaths(share)) {
    const name = `${doc.kind === 'cv' ? 'Cv' : 'Motivatiebrief'}.pdf`
    const { data } = await admin.storage
      .from('profile-shares')
      .createSignedUrl(doc.path, SECONDS_A_FILE_LINK_WORKS, share.allows_download ? { download: name } : undefined)
    if (data?.signedUrl) documents.push({ kind: doc.kind, url: data.signedUrl })
  }

  const { error: logError } = await admin.from('profile_share_views').insert({
    share_id: share.id,
    action: request.action,
    viewer_name: request.viewer?.name ?? null,
    viewer_organisation: request.viewer?.organisation ?? null,
  })
  if (logError) console.error('share-view: writing down the look failed', logError.message)

  return json(shareView(share, items, documents, files, verified))
})
