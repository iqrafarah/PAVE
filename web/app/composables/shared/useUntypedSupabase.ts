import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * The Supabase client without table types. `app/types/database.types.ts` has not been generated yet, which makes
 * every insert and update `never`. Replace the uses with `useSupabaseClient()` once the types exist.
 */
export function useUntypedSupabase() {
  return useSupabaseClient() as unknown as SupabaseClient;
}
