export interface PostgrestErrorLike {
  code?: string;
}

// PostgREST answers a table that does not exist with PGRST205 (Postgres: 42P01).
const MISSING_TABLE_CODES = ['PGRST205', '42P01'];
// A column that does not exist: PGRST204 on insert or update, 42703 in a select.
const MISSING_COLUMN_CODES = ['PGRST204', '42703'];

export function isMissingTable(error: PostgrestErrorLike | null) {
  return Boolean(error?.code && MISSING_TABLE_CODES.includes(error.code));
}

export function isMissingColumn(error: PostgrestErrorLike | null) {
  return Boolean(error?.code && MISSING_COLUMN_CODES.includes(error.code));
}
