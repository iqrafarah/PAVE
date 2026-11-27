import type { H3Event } from 'h3';
import type { EmailRef } from '#shared/types/email';
import { emailError } from './account';

// Reading what the browser sends: only well-formed folder and UID pairs get through.

const MAX_REFS = 500;

export function isRef(value: unknown): value is EmailRef {
  const ref = value as EmailRef;
  return typeof ref?.folder === 'string' && ref.folder.length > 0 && ref.folder.length < 200 && Number.isInteger(ref.uid) && ref.uid > 0;
}

export async function readRefs(event: H3Event) {
  const body = await readBody<{ refs?: unknown }>(event);
  const refs = Array.isArray(body?.refs) ? body.refs : null;
  if (!refs || !refs.length || refs.length > MAX_REFS || !refs.every(isRef)) throw emailError('invalid');
  return refs as EmailRef[];
}
