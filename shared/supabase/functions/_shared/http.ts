import { createClient } from 'npm:@supabase/supabase-js@2';

export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export const admin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  { auth: { persistSession: false } },
);

export function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

export async function readBody(request: Request) {
  const body = await request.json().catch(() => ({}));
  return (key: string) => {
    const value = body[key];
    return typeof value === 'string' ? value : '';
  };
}

export async function sha256Hex(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export function servePost(handler: (request: Request) => Promise<Response>) {
  Deno.serve(async (request) => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
    if (request.method !== 'POST') return respond(405, { error: 'method_not_allowed' });

    try {
      return await handler(request);
    } catch (error) {
      console.error('Request failed', error);
      return respond(500, { error: 'server_error' });
    }
  });
}
