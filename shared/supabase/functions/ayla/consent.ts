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

/** An answer as it is judged: lowercase, without punctuation, and without the "eh" or "nou" people start with. */
function heard(text: string): string {
  return text.toLocaleLowerCase('nl').replace(/[.,!…;:]/g, ' ').replace(/\s+/g, ' ').trim().replace(/^(?:(?:eh|ehm|uh|uhm|nou|hmm|hm|tja|oh|nou ja|eigenlijk) )+/, '')
}

/** A no, also when it starts as a yes ("oké, nee toch niet") or comes without the word ("laat maar", "nu even niet"). */
export function saysNo(text: string): boolean {
  // "Niet alleen mijn diploma" asks for more, and "laat maar zien" asks to see it: neither is a no.
  const said = heard(text).replace(/\bniet alleen\b/g, ' ').replace(/\blaat maar (zien|komen|horen|weten)\b/g, ' ').replace(/\s+/g, ' ').trim()
  if (said.split(' ').length > 9) return false
  return said === 'niet' || /^(nee|neen|no|nope|liever niet|nu (even )?niet|hoeft niet|laat maar|doe maar niet|niet nodig|niet doen|nee dank)\b/.test(said)
    || /\b(liever niet|toch niet|doe maar niet|hoeft niet|laat maar|nu even niet)\b/.test(said)
}

/** Whole phrases that mean yes, and the words a yes may be made of. Anything else in the answer makes it more than a yes. */
const YES_PHRASES = /\b((doe|kijk|ga|zoek|begin|toe) (dan )?maar|ga je gang|geen probleem|zeker weten|van mij mag het|laat maar (zien|komen|horen))\b/g
const YES_WORDS = new Set(['ja', 'jazeker', 'jawel', 'jahoor', 'jep', 'yep', 'yes', 'sure', 'graag', 'prima', 'oke', 'oké', 'ok', 'okay', 'goed', 'top', 'tuurlijk', 'natuurlijk', 'uiteraard', 'absoluut', 'zeker', 'akkoord', 'mag', 'fijn'])
const YES_FILLERS = new Set(['is', 'dat', 'wel', 'helemaal', 'hoor', 'gerust', 'dan', 'hoor'])

/**
 * A plain yes and nothing more: every word is part of saying yes. "Ja, maar alleen mijn stage", "ja ik wil zelf
 * kiezen" and "mag ik eerst iets vragen" say more than yes, so she then asks again instead of looking.
 */
export function saysYes(text: string): boolean {
  if (text.includes('?') || saysNo(text)) return false
  const words = heard(text).replace(YES_PHRASES, 'ja').split(' ').filter(Boolean)
  if (!words.length || words.length > 6 || /^(is|mag) dat\b/.test(words.join(' '))) return false
  return words.every((word) => YES_WORDS.has(word) || YES_FILLERS.has(word)) && words.some((word) => YES_WORDS.has(word))
}
const MAX_PURPOSE_LENGTH = 140

/**
 * "Zoek opnieuw met alles uit mijn kluis", "gebruik mijn hele kluis": the user says in so many words that Ayla may use
 * the vault, which is a yes without her asking. A question about it ("gebruik je alles uit mijn kluis?"), a remark
 * that only names the vault ("ik heb mijn hele kluis opgeruimd") and anything with "niet" or "geen" give nothing away.
 */
export function grantsWholeVault(text: string): boolean {
  const said = heard(text.replace(/\?/g, ' '))
  if (/^(staat|staan|is|zijn|wat|welke|welk|waar|hoe|heb|zit|zitten|waarom|wanneer|wie)\b/.test(said)) return false
  // "Niet alleen mijn diploma" asks for more, not less.
  if (/\b(niet|geen|nooit)\b/.test(said.replace(/\bniet alleen\b/g, ' '))) return false
  const mine = "(mijn|m'n|de)"
  const whole = '(hele|volledige|complete)'
  return new RegExp(`\\b(met|op basis van|aan de hand van) (alles|al het bewijs) (uit|in|van) ${mine} (${whole} )?kluis\\b`).test(said)
    || new RegExp(`\\b(met|op basis van|aan de hand van) ${mine} ${whole} kluis\\b`).test(said)
    // "Gebruik je …" asks; "gebruik …" tells.
    || new RegExp(`\\b(gebruik|neem|pak)\\b(?! (je|jij)\\b).*(\\b${mine} ${whole} kluis\\b|\\balles (uit|in|van) ${mine} kluis\\b)`).test(said)
    || new RegExp(`\\b(kijk|zoek) in ${mine} ${whole} kluis\\b`).test(said)
    || new RegExp(`\\bmag\\b.*(\\b${mine} ${whole} kluis\\b|\\balles (uit|in|van) ${mine} kluis\\b).*\\b(gebruiken|bekijken|zien|inzien)\\b`).test(said)
}

/**
 * "Kijk niet meer in mijn kluis", "ik trek mijn toestemming in": from here on she may not look, until asked again.
 * It takes a word for looking or using: "mijn diploma staat niet meer in mijn kluis" takes nothing back.
 */
export function revokesVault(text: string): boolean {
  const said = heard(text.replace(/\?/g, ' '))
  return /\b(kijk|gebruik|lees|zoek)\b.*\b(niet meer|niet langer)\b.*\bkluis\b/.test(said)
    || /\b(stop met|hou op met)\b.*\bkluis\b/.test(said)
    || /\bkluis\b.*\b(niet meer|niet langer)\b.*\b(gebruiken|bekijken|zien|inzien|kijken|lezen)\b/.test(said)
    || /\b(niet meer|niet langer)\b.*\bkluis\b.*\b(gebruiken|bekijken|zien|inzien|kijken|lezen)\b/.test(said)
    || /\b(trek|intrekken|ingetrokken)\b.*\b(toestemming|kluis)\b/.test(said)
    || /\btoestemming\b.*\b(in ?trek|intrekken|terug)\b/.test(said)
}

/**
 * The last thing the user said about the vault of their own accord was taking it back. Then the item that is open
 * does not show either, until the user allows it again.
 */
export function vaultRevoked(history: ConsentTurn[], request: Pick<AylaRequest, 'text'>): boolean {
  const turns: ConsentTurn[] = [...history, { role: 'user', text: request.text }]
  let revoked = false
  for (let i = 0; i < turns.length; i++) {
    if (turns[i].role !== 'user') continue
    if (revokesVault(turns[i].text)) revoked = true
    else if (grantsWholeVault(turns[i].text) || (turns[i - 1]?.role === 'ayla' && turns[i - 1].askedVault && saysYes(turns[i].text))) revoked = false
  }
  return revoked
}

export function vaultConsent(history: ConsentTurn[], request: Pick<AylaRequest, 'text' | 'context'>): VaultConsent {
  if (request.context?.screen === 'vaultItem') return 'granted'
  // Items picked for the conversation are a yes for those items; picked right after Ayla asked ("Kies zelf"), she goes
  // on with what she asked it for.
  if (request.context?.itemIds?.length) return history.at(-1)?.role === 'ayla' && history.at(-1)?.askedVault ? 'justGranted' : 'granted'
  const turns: ConsentTurn[] = [...history, { role: 'user', text: request.text }]
  let consent: VaultConsent = 'notAsked'
  for (let i = 0; i < turns.length; i++) {
    // Said by the user without being asked: a yes from that moment on, or a no when it is taken back.
    if (turns[i].role === 'user' && revokesVault(turns[i].text)) consent = 'declined'
    else if (turns[i].role === 'user' && grantsWholeVault(turns[i].text)) consent = i === turns.length - 1 ? 'justGranted' : 'granted'
    const next = turns[i + 1]
    if (!next || turns[i].role !== 'ayla' || !turns[i].askedVault || next.role !== 'user') continue
    // A no is heard first: "oké, nee toch niet" is a no.
    if (saysNo(next.text)) consent = 'declined'
    else if (saysYes(next.text)) consent = i + 1 === turns.length - 1 ? 'justGranted' : 'granted'
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
  // A model that writes the word instead of leaving it empty is not asking for anything.
  if (purpose.length < 3 || /^(null|geen|nvt|n\.v\.t\.?|niets|-+)$/i.test(purpose)) return null
  if (purpose.length > MAX_PURPOSE_LENGTH) purpose = `${purpose.slice(0, MAX_PURPOSE_LENGTH - 1).replace(/\s+\S*$/, '')}…`
  return purpose.charAt(0).toLowerCase() + purpose.slice(1)
}

export function consentQuestion(purpose: string): string {
  return `Mag ik in je kluis kijken om ${purpose}?`
}
