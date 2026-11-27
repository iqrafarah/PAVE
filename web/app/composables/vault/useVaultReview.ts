import { FunctionsHttpError } from '@supabase/supabase-js';

const FUNCTION_NAME = 'vault-review';

export type VaultReviewAction = 'inbox' | 'detail' | 'create' | 'resolve' | 'contactPhotos';

type VaultReviewResult<T> = { data: T; errorCode: null } | { data: null; errorCode: string };

/** The error code in the body (`{ error: "no_reviewers" }`), else "unavailable". */
async function readErrorCode(error: unknown) {
  if (!(error instanceof FunctionsHttpError)) return navigator.onLine ? 'unavailable' : 'offline';
  const response = error.context as Response;
  const body = (await response.json().catch(() => null)) as { error?: unknown } | null;
  return typeof body?.error === 'string' ? body.error : 'unavailable';
}

/**
 * The vault-review Edge Function: the only way to read the inbox, see evidence under review and create or decide a
 * request (docs/verificatie.md). The signed-in session goes along, so the function knows who asks.
 */
export function useVaultReview() {
  const supabase = useUntypedSupabase();

  async function call<T>(action: VaultReviewAction, body: Record<string, unknown> = {}): Promise<VaultReviewResult<T>> {
    const { data, error } = await supabase.functions.invoke<T>(FUNCTION_NAME, { body: { action, ...body } });
    if (error || data === null) return { data: null, errorCode: await readErrorCode(error) };
    return { data, errorCode: null };
  }

  return { call };
}
