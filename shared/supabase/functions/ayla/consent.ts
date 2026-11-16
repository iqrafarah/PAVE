// Whether Ayla may look in the vault in this conversation. The first time a question needs it, she asks "Mag ik in je
// kluis kijken om …?" with Ja and Nee; the answer holds for the rest of the conversation, so she does not ask again.
// Asking about one item ("Vraag Ayla over dit bewijs") is consent in itself. Which items she then sees is still up to
// the user per item ("Ayla mag dit bekijken en gebruiken", see vault.ts).
import type { AylaRequest } from './contract.ts'

export type VaultConsent = 'notAsked' | 'granted' | 'justGranted' | 'declined'

/** A message of the conversation as the consent check needs it: an Ayla turn says whether it asked for the vault. */
export interface ConsentTurn { role: 'user' | 'ayla'; text: string; askedVault?: boolean }

export const CONSENT_QUESTION_CHOICES = [{ id: 'yes', label: 'Ja' }, { id: 'no', label: 'Nee' }]

const YES = /^(ja|jazeker|ja graag|graag|prima|oké|oke|ok|okay|goed|is goed|mag|yes)\b/i
const NO = /^(nee|liever niet|niet|no|nope)\b/i
const MAX_PURPOSE_LENGTH = 140

export function vaultConsent(history: ConsentTurn[], request: Pick<AylaRequest, 'text' | 'context'>): VaultConsent {
  if (request.context?.screen === 'vaultItem') return 'granted'
  const turns: ConsentTurn[] = [...history, { role: 'user', text: request.text }]
  let consent: VaultConsent = 'notAsked'
  for (let i = 0; i < turns.length - 1; i++) {
    const next = turns[i + 1]
    if (turns[i].role !== 'ayla' || !turns[i].askedVault || next.role !== 'user') continue
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
