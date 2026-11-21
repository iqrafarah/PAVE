// Whether Ayla may look in the vault in this conversation. The first time a question needs it, she asks "Mag ik in je
// kluis kijken om …?" with Ja and Nee; the answer holds for the rest of the conversation, so she does not ask again.
// Asking about one item ("Vraag Ayla over dit bewijs") is consent in itself. Which items she then sees is still up to
// the user per item ("Ayla mag dit bekijken en gebruiken", see vault.ts).
import type { AylaRequest } from './contract.ts'

export type VaultConsent = 'notAsked' | 'granted' | 'justGranted' | 'declined'

/** A message of the conversation as the consent check needs it: an Ayla turn says whether it asked for the vault. */
export interface ConsentTurn { role: 'user' | 'ayla'; text: string; askedVault?: boolean }

export const CONSENT_QUESTION_CHOICES = [{ id: 'yes', label: 'Ja' }, { id: 'no', label: 'Nee' }]
/** "Kies zelf": the app opens the vault picker and the user says which items Ayla may use for this conversation. */
export const CONSENT_CHOOSE = { id: 'choose', label: 'Kies zelf' }

/** Ja, Kies zelf and Nee where the app has the picker behind that choice; elsewhere Ja and Nee. */
export function consentChoices(device: AylaRequest['device']) {
  return device === 'phone' ? [CONSENT_QUESTION_CHOICES[0], CONSENT_CHOOSE, CONSENT_QUESTION_CHOICES[1]] : CONSENT_QUESTION_CHOICES
}

const YES = /^(ja|jazeker|ja graag|graag|prima|oké|oke|ok|okay|goed|is goed|mag|yes)\b/i
const NO = /^(nee|liever niet|niet|no|nope)\b/i
const MAX_PURPOSE_LENGTH = 140

/**
 * "Zoek opnieuw met alles uit mijn kluis", "gebruik mijn hele kluis": the user says in so many words that Ayla may use
 * the vault, which is a yes without her asking. Not when it is said with "niet" or "geen".
 */
export function grantsWholeVault(text: string): boolean {
  const said = text.toLocaleLowerCase('nl').replace(/[.,!?;:]/g, ' ').replace(/\s+/g, ' ').trim()
  if (/\b(niet|geen|nooit)\b/.test(said)) return false
  return /\b(alles|heel|hele|volledige|complete|al)\b.*\bkluis\b/.test(said) || /\bkluis\b.*\b(helemaal|alles|volledig)\b/.test(said)
}

export function vaultConsent(history: ConsentTurn[], request: Pick<AylaRequest, 'text' | 'context'>): VaultConsent {
  if (request.context?.screen === 'vaultItem') return 'granted'
  // Items picked for the conversation are a yes for those items; picked right after Ayla asked ("Kies zelf"), she goes
  // on with what she asked it for.
  if (request.context?.itemIds?.length) return history.at(-1)?.role === 'ayla' && history.at(-1)?.askedVault ? 'justGranted' : 'granted'
  const turns: ConsentTurn[] = [...history, { role: 'user', text: request.text }]
  let consent: VaultConsent = 'notAsked'
  for (let i = 0; i < turns.length; i++) {
    // Said by the user without being asked: a yes from that moment on.
    if (turns[i].role === 'user' && grantsWholeVault(turns[i].text)) consent = i === turns.length - 1 ? 'justGranted' : 'granted'
    const next = turns[i + 1]
    if (!next || turns[i].role !== 'ayla' || !turns[i].askedVault || next.role !== 'user') continue
    const reply = next.text.trim()
    if (YES.test(reply)) consent = i + 1 === turns.length - 1 ? 'justGranted' : 'granted'
    else if (NO.test(reply)) consent = 'declined'
  }
  return consent
}

export function mayLookInVault(consent: VaultConsent): boolean {
  return consent === 'granted' || consent === 'justGranted'
}

/** What Ayla wants to look for, so it fits "Mag ik in je kluis kijken om …?"; null when there is nothing usable. */
export function cleanPurpose(raw: unknown): string | null {
  if (typeof raw !== 'string') return null
  let purpose = raw.replace(/\s+/g, ' ').trim().replace(/^om\s+/i, '').replace(/[?.!,;:\s]+$/, '')
  if (purpose.length < 3) return null
  if (purpose.length > MAX_PURPOSE_LENGTH) purpose = `${purpose.slice(0, MAX_PURPOSE_LENGTH - 1).replace(/\s+\S*$/, '')}…`
  return purpose.charAt(0).toLowerCase() + purpose.slice(1)
}

export function consentQuestion(purpose: string): string {
  return `Mag ik in je kluis kijken om ${purpose}?`
}
