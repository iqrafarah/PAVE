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

/**
 * Something the shared schema does not have yet: a table, a column or a relation between tables (PGRST200 when a select
 * embeds a table PostgREST does not know). Used to keep working before a migration runs, as iOS does.
 */
export function isNotThereYet(error: PostgrestErrorLike | null) {
  return isMissingTable(error) || isMissingColumn(error) || error?.code === 'PGRST200';
}
