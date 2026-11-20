// Reviewer inbox, evidence access, and ID-bound verification requests for iOS. The service key is
// used only after authenticating the caller and checking the request's trusted recipient set.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { CORS, json, sessionLevel } from '../_shared/http.ts'

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

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } })
  const body = await req.json().catch(() => null) as {
    action?: string; requestId?: string; itemId?: string; organizationId?: string
    locationId?: string; departmentId?: string | null; contactId?: string
    message?: string; outcome?: string; response?: string
  } | null
  if (!body || !['inbox', 'detail', 'create', 'resolve'].includes(body.action ?? '')) return json({ error: 'invalid_request' }, 400)

  try {
    const { data: assignments, error: assignmentError } = await admin
      .from('organization_reviewers').select('organization_id').eq('reviewer_id', user.id)
    if (assignmentError) throw assignmentError
    const hasReviewerAssignment = (assignments ?? []).length > 0

    if (body.action === 'create') {
      if (!body.itemId || !body.organizationId || !body.locationId || !body.contactId) return json({ error: 'invalid_request' }, 400)
      if (body.message !== undefined && body.message !== null && typeof body.message !== 'string') return json({ error: 'invalid_request' }, 400)
      if (body.message && body.message.length > 2000) return json({ error: 'message_too_long' }, 400)
      const [{ data: item }, { data: organization, error: organizationError }, { data: location, error: locationError }] = await Promise.all([
        authClient.from('vault_items').select('id,user_id,title,verification_status').eq('id', body.itemId).eq('user_id', user.id).maybeSingle(),
        admin.from('organizations').select('id,name,kind').eq('id', body.organizationId).not('kind', 'is', null).maybeSingle(),
        admin.from('organization_locations').select('id,organization_id,city').eq('id', body.locationId).eq('organization_id', body.organizationId).maybeSingle(),
      ])
      if (organizationError) throw organizationError
      if (locationError) throw locationError
      // Rejected evidence may be sent again; verified evidence first has to change (which makes it toVerify).
      if (!item || !['toVerify', 'rejected'].includes(item.verification_status)) return json({ error: 'item_not_awaiting_verification' }, 409)
      if (!organization) return json({ error: 'organization_not_found' }, 404)
      if (!location) return json({ error: 'invalid_choice' }, 400)

      // Location, then (at a school) a department of that location, then one person there.
      let department: { id: string } | null = null
      if (body.departmentId) {
        const { data, error } = await admin.from('organization_departments')
          .select('id').eq('id', body.departmentId).eq('location_id', location.id).maybeSingle()
        if (error) throw error
        department = data
        if (!department) return json({ error: 'invalid_choice' }, 400)
      }

      const { data: contact, error: contactError } = await admin.from('organization_contacts')
        .select('id,department_id')
        .eq('id', body.contactId).eq('location_id', location.id).eq('is_active', true).maybeSingle()
      if (contactError) throw contactError
      if (!contact || contact.department_id !== (department?.id ?? null)) {
        return json({ error: 'invalid_choice' }, 400)
      }

      const { data: activeRequest, error: activeError } = await admin.from('vault_validation_requests')
        .select('id').eq('user_id', user.id).eq('item_id', item.id).eq('organization_id', organization.id).eq('status', 'pending').maybeSingle()
      if (activeError) throw activeError
      if (activeRequest) return json({ error: 'already_pending' }, 409)
      const { data: request, error: createError } = await admin.from('vault_validation_requests').insert({
        user_id: user.id, item_id: item.id, organisation_name: organization.name,
        organization_id: organization.id, location_id: location.id,
        department_id: department?.id ?? null, contact_id: contact.id,
        message: body.message?.trim() || null, status: 'pending',
      }).select('id,requested_at').single()
      // The database partial unique index is the race-safe duplicate guard; keep the
      // friendly response in sync when two submissions arrive at the same time.
      if (createError?.code === '23505') return json({ error: 'already_pending' }, 409)
      if (createError || !request) throw createError ?? new Error('request insert returned no row')
      const { data: recipients, error: recipientError } = await admin.rpc('vault_validation_recipients', { p_request_id: request.id })
      if (recipientError) {
        await admin.from('vault_validation_requests').delete().eq('id', request.id).eq('status', 'pending')
        throw recipientError
      }
      if (!recipients?.length) {
        await admin.from('vault_validation_requests').delete().eq('id', request.id).eq('status', 'pending')
        return json({ error: 'no_reviewers' }, 409)
      }
      const notifications = recipients.map(({ reviewer_id }: { reviewer_id: string }) => ({
        recipient_id: reviewer_id, kind: 'verification_request', title: 'Verificatie aanvraag',
        body: item.title, validation_request_id: request.id,
        dedupe_key: `vault-validation:${request.id}`,
      }))
      const { error: notificationError } = await admin.from('user_notifications').insert(notifications)
      if (notificationError) {
        await admin.from('vault_validation_requests').delete().eq('id', request.id).eq('status', 'pending')
        throw notificationError
      }
      // A new request on rejected evidence: back to toVerify, so the reviewer can decide it again.
      if (item.verification_status === 'rejected') {
        const { error: resetError } = await admin.from('vault_items')
          .update({ verification_status: 'toVerify', updated_at: new Date().toISOString() })
          .eq('id', item.id).eq('user_id', user.id).eq('verification_status', 'rejected')
        if (resetError) {
          await admin.from('vault_validation_requests').delete().eq('id', request.id).eq('status', 'pending')
          throw resetError
        }
      }
      return json({ id: request.id, requestedAt: request.requested_at })
    }

    if (body.action === 'resolve') {
      if (!body.requestId || !['verified', 'rejected'].includes(body.outcome ?? '')) return json({ error: 'invalid_request' }, 400)
      if (body.response !== undefined && body.response !== null && typeof body.response !== 'string') return json({ error: 'invalid_request' }, 400)
      if (body.response && body.response.length > 2000) return json({ error: 'response_too_long' }, 400)
      if (body.outcome === 'rejected' && !body.response?.trim()) return json({ error: 'response_required' }, 400)
      const { data: request, error: requestError } = await admin.from('vault_validation_requests')
        .select('id,organization_id,status').eq('id', body.requestId).maybeSingle()
      if (requestError) throw requestError
      if (!request || request.status !== 'pending' || !request.organization_id) return json({ error: 'not_found' }, 404)
      const { data: recipients, error: recipientError } = await admin.rpc('vault_validation_recipients', { p_request_id: request.id })
      if (recipientError) throw recipientError
      if (!(recipients ?? []).some((recipient: { reviewer_id: string }) => recipient.reviewer_id === user.id)) return json({ error: 'not_found' }, 404)
      const { data, error } = await admin.rpc('resolve_vault_validation_request', {
        p_request_id: body.requestId,
        p_action: body.outcome,
        p_response: body.response?.trim() || null,
        p_actor_id: user.id,
      })
      if (error) {
        console.error('vault-review resolve failed', error)
        return json({ error: 'decision_failed' }, 409)
      }
      return json(data)
    }

    if (body.action === 'inbox') {
      // Deleted notifications stay restorable for 7 days ("Recent verwijderd"), then they are gone for good.
      const restorableSince = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
      const { error: purgeError } = await admin.from('user_notifications')
        .delete().eq('recipient_id', user.id).lt('deleted_at', restorableSince)
      if (purgeError) throw purgeError

      const { data: notices, error } = await admin.from('user_notifications')
        .select('id,kind,title,body,conversation_id,validation_request_id,vault_item_id,created_at,read_at,deleted_at,dedupe_key')
        .eq('recipient_id', user.id).order('created_at', { ascending: false }).limit(100)
      if (error) throw error

      const visible = []
      for (const notice of notices ?? []) {
        if (notice.kind === 'verification_request') {
          if (!notice.validation_request_id) continue
          const { data: request } = await admin.from('vault_validation_requests')
            .select('id,user_id,item_id,organization_id,organisation_name,message,status,requested_at')
            .eq('id', notice.validation_request_id).eq('status', 'pending').maybeSingle()
          if (!request || !request.organization_id) continue
          const { data: recipients, error: recipientError } = await admin.rpc('vault_validation_recipients', { p_request_id: request.id })
          if (recipientError) throw recipientError
          if (!(recipients ?? []).some((recipient: { reviewer_id: string }) => recipient.reviewer_id === user.id)) continue
          const [{ data: item }, { data: profile }] = await Promise.all([
            admin.from('vault_items').select('id,title,category,organisation_name,verification_status').eq('id', request.item_id).eq('user_id', request.user_id).maybeSingle(),
            admin.from('profiles').select('full_name,preferred_name').eq('id', request.user_id).maybeSingle(),
          ])
          if (!item) continue
          visible.push({
            id: notice.id, kind: notice.kind, title: notice.title,
            personName: profile?.preferred_name || profile?.full_name || 'Lerende',
            date: notice.created_at, isUnread: notice.read_at == null, deletedAt: notice.deleted_at,
            validationRequestID: request.id, vaultItemID: item.id,
            learnerName: profile?.preferred_name || profile?.full_name || 'Lerende',
            learnerOrganization: request.organisation_name,
            documentName: item.title, documentType: item.category,
          })
        } else if ((notice.kind === 'evidence_verified' || notice.kind === 'evidence_rejected') && notice.validation_request_id && notice.vault_item_id) {
          // A decision stays in the inbox as history, also once the evidence is changed or sent again.
          const [{ data: item }, { data: request }] = await Promise.all([
            admin.from('vault_items').select('id,title').eq('id', notice.vault_item_id).eq('user_id', user.id).maybeSingle(),
            admin.from('vault_validation_requests').select('organisation_name')
              .eq('id', notice.validation_request_id).eq('user_id', user.id).maybeSingle(),
          ])
          if (!item) continue
          visible.push({
            id: notice.id, kind: notice.kind, title: notice.title,
            personName: request?.organisation_name || 'Kluis',
            date: notice.created_at, isUnread: notice.read_at == null, deletedAt: notice.deleted_at,
            validationRequestID: notice.validation_request_id, vaultItemID: item.id,
            documentName: item.title,
          })
        } else if (notice.kind === 'conversation' && notice.conversation_id) {
          const { data: conversation } = await admin.from('ayla_conversations').select('id,title,user_id')
            .eq('id', notice.conversation_id).maybeSingle()
          if (!conversation || conversation.user_id !== user.id) continue
          visible.push({
            id: notice.id, kind: notice.kind, title: notice.title || conversation.title,
            personName: 'Ayla', date: notice.created_at, isUnread: notice.read_at == null, deletedAt: notice.deleted_at,
            conversationID: conversation.id,
          })
        }
      }
      return json({ audience: hasReviewerAssignment ? 'administrator' : 'learner', notifications: visible })
    }

    if (!body.requestId) return json({ error: 'invalid_request' }, 400)
    const { data: request, error: requestError } = await admin.from('vault_validation_requests')
      .select('id,user_id,item_id,organization_id,organisation_name,message,status,requested_at')
      .eq('id', body.requestId).maybeSingle()
    if (requestError) throw requestError
    if (!request || request.status !== 'pending' || !request.organization_id) {
      return json({ error: 'not_found' }, 404)
    }
    const { data: recipients, error: recipientError } = await admin.rpc('vault_validation_recipients', { p_request_id: request.id })
    if (recipientError) throw recipientError
    if (!(recipients ?? []).some((recipient: { reviewer_id: string }) => recipient.reviewer_id === user.id)) return json({ error: 'not_found' }, 404)

    const [{ data: item, error: itemError }, { data: profile }, { data: files, error: filesError }, { data: skills }] = await Promise.all([
      admin.from('vault_items').select('*').eq('id', request.item_id).eq('user_id', request.user_id).maybeSingle(),
      admin.from('profiles').select('full_name,preferred_name').eq('id', request.user_id).maybeSingle(),
      admin.from('vault_item_files').select('id,file_name,mime_type,storage_path,role').eq('item_id', request.item_id).eq('user_id', request.user_id),
      admin.from('vault_item_skills').select('name').eq('item_id', request.item_id).eq('user_id', request.user_id).eq('status', 'accepted'),
    ])
    if (itemError) throw itemError
    if (filesError) throw filesError
    if (!item) return json({ error: 'not_found' }, 404)

    const signedFiles = await Promise.all((files ?? []).map(async (file) => {
      const { data, error } = await admin.storage.from('pave-vault').createSignedUrl(file.storage_path, 300)
      if (error) throw error
      return { id: file.id, name: file.file_name, mimeType: file.mime_type, role: file.role, url: data.signedUrl }
    }))
    return json({
      request: {
        id: request.id, status: request.status, requestedAt: request.requested_at,
        message: request.message, learnerName: profile?.preferred_name || profile?.full_name || 'Lerende',
      },
      item: { ...item, skills: (skills ?? []).map((skill) => skill.name), files: signedFiles },
    })
  } catch (error) {
    console.error('vault-review failed', error)
    return json({ error: 'unavailable' }, 500)
  }
})
