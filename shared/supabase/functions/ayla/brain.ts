import { ACTIONS, type ActionKind, type ActionResult, type AppAction, needsConfirmation, type AylaReply, type AylaRequest, type Block, type Status, CATEGORIES, type Category, type RequirementLink, type Screen, SCREENS, type Vacancy } from './contract.ts'
import type { AllowedVault } from './vault.ts'
import { cleanPurpose, CONSENT_QUESTION_CHOICES, consentChoices, consentQuestion, mayLookInVault, type VaultConsent, vaultConsent } from './consent.ts'
import { cleanMemories, type Memory, type MemorySuggestion, usedNotes } from './memory.ts'
import type { ContentPart, ChatMessage, Complete, Effort } from './openrouter.ts'
import { buildSystemPrompt } from './prompt.ts'
import { vaultProposal } from './proposal.ts'
import { type FoundVacancy, logoUrl, mergeFound, type SearchVacancies } from './vacancies.ts'

/** A message so far. An Ayla turn says whether it asked to look in the vault, for the consent of this conversation. */
export interface PastMessage { role: 'user' | 'ayla'; text: string; askedVault?: boolean }

export interface BrainInput {
  request: AylaRequest
  conversationId: string
  history: PastMessage[]
  firstName?: string
  /** What the user let Ayla remember. Missing means Ayla remembers nothing. */
  memory?: Memory
  /** The project of this conversation, if any. */
  project?: { name: string; instructions: string; sourceIds?: string[] }
  /** The vault items the user allowed Ayla to use. Missing means she sees none. She only sees them once the user said
   * Ja to looking in the vault in this conversation (see consent.ts). */
  vault?: AllowedVault
  /** Called with the text of the answer so far, while the model writes it. */
  onText?: (text: string) => void
  /** Called when Ayla starts something that takes a while, such as searching vacancies. */
  onStatus?: (status: Status) => void
  /** Stops the answer, for instance when the user taps stop. */
  signal?: AbortSignal
  /** Called with a short title for a new conversation, when the model gives one. */
  onTitle?: (title: string) => void
}

export interface BrainDeps {
  complete: Complete
  /** Missing when no source for vacancies is configured. */
  searchVacancies?: SearchVacancies
  newId: () => string
  /** Whether a site the model named for a company really is there; without it no logos are shown. */
  siteExists?: (domain: string) => Promise<boolean>
}

export const HISTORY_LIMIT = 20
/** How many messages are read to know whether the user let Ayla look in the vault in this conversation. */
export const CONSENT_HISTORY_LIMIT = 100

/** A row of ayla_messages as the function reads it. */
export interface StoredMessage { role: 'user' | 'ayla'; text: string; reply?: Partial<AylaReply> | null }

/**
 * A stored message for the brain. When Ayla asked to look in the vault, her question was not part of her text, so it is
 * added: the model then knows what a Ja answers.
 */
export function toPastMessage(message: StoredMessage): PastMessage {
  // A user message keeps the names of its files, so the model knows later which file went with what.
  const names = (message.reply as { attachments?: unknown } | null | undefined)?.attachments
  if (message.role === 'user') {
    const files = Array.isArray(names) ? names.filter((n): n is string => typeof n === 'string' && !!n) : []
    return { role: 'user', text: files.length ? `${message.text}\n(bijlagen: ${files.join(', ')})` : message.text }
  }
  // The cards under an answer are not in its text: without them a later "de tweede" or "meer zoals die" means nothing.
  const shown = shownVacancies(message.reply?.blocks)
  const said = shown ? `${message.text}\n${shown}` : message.text
  const asked = !!message.reply?.accessRequest
  if (!asked) return { role: message.role, text: said }
  const question = message.reply?.question?.text
  return { role: 'ayla', text: question ? `${said}\n${question}` : said, askedVault: true }
}

/** The vacancies an answer showed, in the order of the cards, with what was searched for. */
function shownVacancies(blocks: Block[] | undefined): string | null {
  const block = (blocks ?? []).find((b): b is Extract<Block, { type: 'vacancies' }> => b?.type === 'vacancies' && Array.isArray(b.items) && b.items.length > 0)
  if (!block) return null
  const search = block.search
  const terms = search ? `, gezocht op "${search.what}"${search.also ? ` en "${search.also}"` : ''}${search.where ? ` in ${search.where}` : ''}` : ''
  const list = block.items.slice(0, 8).map((v, i) => {
    const fit = [v.matches?.length ? `past: ${v.matches.map((m) => m.skill).join(', ')}` : '', v.skillGap?.length ? `mist: ${v.skillGap.map((m) => m.skill).join(', ')}` : ''].filter(Boolean).join('; ')
    return `${i + 1}. ${v.title} bij ${v.company}${v.city ? ` in ${v.city}` : ''}${fit ? ` [${fit}]` : ''}`
  })
  return `(Getoonde vacatures${terms}: ${list.join('; ')})`
}
const NAVIGABLE = new Set<Screen>(['home', 'vault', 'addEvidence', 'plans', 'vacancies', 'profile', 'settings'])
const FALLBACK_TEXT = 'Sorry, dat lukte me even niet. Wil je het nog een keer vragen?'

interface ModelOutput {
  text: string
  question: { text: string; choices: { id: string; label: string }[] } | null
  navigation: { screen: string; item?: number | null } | null
  vacancySearch: { what: string; where: string; also: string | null } | null
  vacancyMatches: unknown
  vacancySites: unknown
  title: string | null
  memories: unknown
  usedMemories: unknown
  usedVaultItems: unknown
  vaultItem: unknown
  askVault: unknown
  actions: unknown
  continues: boolean
}

/** One turn of the conversation: the prompt in layers, the model, and a reply in the contract format. */
export async function answer(input: BrainInput, deps: BrainDeps): Promise<AylaReply> {
  const { request } = input
  const memory: Memory = input.memory ?? { status: 'unavailable' }
  // Sources the user put in the project are a standing yes to look at those items (still only the allowed ones).
  const asked = vaultConsent(input.history, request)
  const consent = asked === 'notAsked' && input.project?.sourceIds?.length ? 'granted' : asked
  const mayLook = mayLookInVault(consent)
  // Items the user picked for this conversation are all Ayla uses, not the rest of what she may see.
  const chosen = request.context?.itemIds
  const allowed = mayLook ? input.vault : undefined
  const vault = allowed?.status === 'on' && chosen?.length ? { ...allowed, items: allowed.items.filter((item) => chosen.includes(item.id)) } : allowed
  const messages: ChatMessage[] = [
    { role: 'system', content: buildSystemPrompt({ device: request.device, input: request.input, firstName: input.firstName, context: request.context, memory, project: input.project, vault, vaultConsent: consent, app: request.app }) },
    ...pastMessages(input.history.slice(-HISTORY_LIMIT)),
    // What came of her actions is the app speaking, not the user: it is said so, and she goes on from there.
    { role: 'user', content: request.results?.length ? resultsMessage(request.results) : withAttachments(request) },
  ]
  const effort = effortFor(request, mayLook)

  let lastText = ''
  const showText = (content: string) => {
    if (!input.onText) return
    const text = stripMarkdown(partialText(content))
    if (text && text !== lastText) {
      lastText = text
      input.onText(text)
    }
  }
  // Room for the whole answer with its actions: an answer that is cut off loses what comes last.
  const options = { signal: input.signal, onContent: input.onText ? showText : undefined, effort, maxTokens: 900 }

  // Ayla asks to look in the vault: the rest of what the model writes does not count for this turn, so it stops there
  // and the Ja and Nee show at once.
  const first = new AbortController()
  if (input.signal?.aborted) first.abort()
  input.signal?.addEventListener('abort', () => first.abort())
  let asksVault: ModelOutput | null = null
  // The search starts as soon as the model wrote what to search for, while it still writes the rest.
  let early: (SearchTerms & { found: Promise<SearchResult> }) | null = null
  const firstOptions = {
    effort,
    maxTokens: 900,
    signal: first.signal,
    onContent: (content: string) => {
      showText(content)
      const terms = early ? null : vacancySearchSoFar(content)
      if (terms) {
        input.onStatus?.(searchStatus(terms))
        early = { ...terms, found: searchTerms(deps.searchVacancies, terms) }
      }
      if (mayLook || asksVault) return
      const ask = consentAskSoFar(content)
      if (ask) {
        asksVault = ask
        first.abort()
      }
    },
  }
  let output: ModelOutput
  try {
    output = parseOutput((await deps.complete(messages, firstOptions)).content)
  } catch (error) {
    if (!asksVault || input.signal?.aborted) throw error
    output = asksVault
  }
  // She said she would search and did not: she is told so and does it now, instead of the user having to say "ga".
  if (mayLook && deps.searchVacancies && !request.results?.length && announcesSearchOnly(output)) {
    const nudge: ChatMessage[] = [
      { role: 'assistant', content: JSON.stringify(output) },
      { role: 'system', content: 'Je zegt dat je vacatures gaat zoeken, maar vacancySearch is leeg: er gebeurt nu niets. Zoek in dit antwoord: vul vacancySearch (what, where, also) op basis van wat de gebruiker vroeg en de items die je ziet, en zeg in text kort waarop je zoekt. Zet actions op [].' },
    ]
    const again = parseOutput((await deps.complete([...messages, ...nudge], { ...options, effort: 'hard' as const })).content)
    if (again.vacancySearch) {
      messages.push(...nudge)
      output = { ...again, memories: Array.isArray(again.memories) && again.memories.length ? again.memories : output.memories, title: again.title ?? output.title }
    }
  }
  // The cards of a search open by themselves: an action that opens or saves one of them comes too soon.
  if (output.vacancySearch && Array.isArray(output.actions)) {
    output.actions = (output.actions as Record<string, unknown>[]).filter((action) => !['openVacancy', 'saveVacancy', 'openSavedVacancies'].includes(String(action?.do)))
  }
  // The first answer heard what the user said; the second one only talks about the vacancies.
  const heard = cleanMemories(output.memories, memory)
  const firstActions = output.actions
  const firstUsed = usedNotes(output.usedMemories, memory)
  const title = cleanTitle(output.title)
  if (title && input.onTitle) input.onTitle(title)
  const blocks: Block[] = []

  if (output.vacancySearch) {
    const terms = output.vacancySearch
    const started = early as (SearchTerms & { found: Promise<SearchResult> }) | null
    const sameSearch = started && started.what === terms.what && started.where === terms.where && started.also === terms.also
    if (!sameSearch) input.onStatus?.(searchStatus(terms))
    const found = sameSearch ? await started.found : await searchTerms(deps.searchVacancies, terms)
    if (found.status === 'ok' && found.items.length) {
      const picked = vault?.status === 'on' && chosen?.length ? { chosen: vault.items.length } : {}
      input.onStatus?.({ kind: 'vacancyMatch', count: found.items.length, withVault: mayLook, ...picked })
    }
    messages.push({ role: 'assistant', content: JSON.stringify(output) }, { role: 'system', content: describeSearch(found, mayLook, consent) })
    // Comparing every vacancy with the vault is the hardest thing she does, and its answer is long.
    const matching = mayLook && found.status === 'ok' && found.items.length > 0
    output = parseOutput((await deps.complete(messages, matching ? { ...options, effort: 'hard' as const, maxTokens: 1500 } : options)).content)
    if (found.status === 'ok' && found.items.length && request.device !== 'watch') {
      // What fits and what is missing only with the vault allowed, and only what the vacancy text really says. The
      // best fit comes first.
      // A logo for the companies whose own site the model named: only a name that fits and a site that is there.
      const withLogo = await withLogos(found.items, output.vacancySites, deps.siteExists)
      const items = mayLook ? bestFirst(withMatches(withLogo, output.vacancyMatches)) : withLogo.map((f) => f.vacancy)
      blocks.push({ type: 'vacancies', items, search: { what: terms.what, where: terms.where, ...(terms.also ? { also: terms.also } : {}) } })
    }
  }

  const reply = toReply(output, blocks, input.conversationId, deps.newId(), vault)
  const later = cleanMemories(output.memories, memory)
  const suggestions: MemorySuggestion[] = later.length ? later : heard
  if (suggestions.length) reply.memories = suggestions
  const laterUsed = usedNotes(output.usedMemories, memory)
  const used = laterUsed.length ? laterUsed : firstUsed
  if (used.length) reply.usedMemories = used
  // A proposal for the vault: the Watch saves it after Ja; the iPhone and the web open adding evidence with it filled in.
  const action = vaultProposal(output.vaultItem, deps.newId(), new Date())
  if (action) reply.proposedAction = action
  // Ayla wants to look in the vault and may not yet: the app asks, with fixed words, before she sees anything. When
  // the model asked it in its text as well, that sentence goes, so the question is asked once; with nothing left to
  // say, the question is the whole answer.
  // A model that asked it in words instead ("Mag ik in je kluis kijken om …?", as its question or in its text) asked
  // for the vault all the same.
  const purpose = mayLook ? null : cleanPurpose(output.askVault) ?? consentAskIn(output.question?.text) ?? consentAskIn(output.text)
  if (purpose) {
    reply.accessRequest = { id: deps.newId(), purpose, categories: [] }
    const question = consentQuestion(purpose)
    const lead = withoutConsentAsk(reply.text)
    reply.text = lead || question
    reply.question = { text: lead ? question : '', choices: consentChoices(request.device) }
    delete reply.navigation
  }
  // What she does in the app herself. What cannot be undone waits for a Ja to a question with fixed words, so a model
  // that says "gedaan" too soon changes nothing.
  // Asking whether she should do something and doing it in the same answer contradict: the question wins, and
  // nothing happens until the user answers.
  const asksFirst = ASKS_BEFORE_DOING.test(reply.text.trim())
  const actions = purpose || asksFirst ? [] : cleanActions(Array.isArray(output.actions) && output.actions.length ? output.actions : firstActions, request.device)
  if (actions.length) {
    reply.actions = actions
    const risky = actions.find((action) => action.confirm)
    if (!risky && output.continues) reply.continues = true
    if (risky) {
      reply.text = CONFIRM_QUESTIONS[risky.do]?.(risky) ?? 'Weet je het zeker?'
      reply.question = { text: '', choices: CONSENT_QUESTION_CHOICES }
      delete reply.navigation
    }
  }
  // The user just said no to what Ayla offered: she does not offer it again, whatever the model wrote.
  if (declinedOffer(input.history, request.text)) {
    delete reply.proposedAction
    if (reply.navigation?.screen === 'addEvidence') delete reply.navigation
    if (reply.question?.choices.some((c) => /^(ja|yes)$/i.test(c.label))) delete reply.question
  }
  return reply
}

const NO_ANSWER = /^(nee|nope|no|liever niet|niet nu|nee bedankt|nee dank je)\b/i

/** The user answers no to a question or offer of Ayla in the last turn. */
export function declinedOffer(history: PastMessage[], text: string): boolean {
  if (!NO_ANSWER.test(text.trim())) return false
  const last = history.at(-1)
  return last?.role === 'ayla'
}

/** What the model asks the vault for when it asks in words; null when it does not ask. */
export function consentAskIn(text: string | null | undefined): string | null {
  const match = text?.match(/\bmag ik\b[^.?!]*\bkluis\b[^.?!]*?\bkijken\b(?:\s+om\s+([^.?!]+))?/i)
  if (!match) return null
  return cleanPurpose(match[1] ?? '') ?? 'te zien wat erin staat'
}

/**
 * Ayla's last question is an open one ("Wat…", "Welke…"), which the user answers in words, not with Ja or Nee. A
 * sentence after it ("Bijvoorbeeld een diploma.") does not change that.
 */
export function endsWithOpenQuestion(text: string): boolean {
  const questions = text.trim().split(/(?<=[.!?])\s+|\n+/).map((s) => s.trim()).filter((s) => s.endsWith('?'))
  const last = questions.at(-1) ?? ''
  return /^(wat|welke?|hoe|wanneer|waar\w*|wie|waarom|hoeveel|hoelang)\b/i.test(last)
}

/** The text without the sentences in which the model itself asks whether it may look in the vault. */
export function withoutConsentAsk(text: string): string {
  const sentences = text.split(/(?<=[.!?])\s+|\n+/).map((s) => s.trim()).filter(Boolean)
  const asksVault = (s: string) =>
    /\bkluis\b/i.test(s) && (/^(mag|kan|zal|zou) ik\b|^(wil je dat|vind je het goed|is het goed)\b|\bin je kluis\b.*\bkijken\b/i.test(s))
  return sentences.filter((s) => !asksVault(s)).join(' ')
}

/**
 * The text field of an answer that is still being written: the model writes JSON, and `text` comes first. An escape
 * cut in half at the end waits for the next piece.
 */
export function partialText(json: string): string {
  const start = json.match(/"text"\s*:\s*"/)
  if (!start || start.index === undefined) return ''
  let text = ''
  for (let i = start.index + start[0].length; i < json.length; i++) {
    const char = json[i]
    if (char === '"') return text
    if (char !== '\\') {
      text += char
      continue
    }
    const next = json[i + 1]
    if (next === undefined) return text
    if (next === 'u') {
      const hex = json.slice(i + 2, i + 6)
      if (hex.length < 4) return text
      text += String.fromCharCode(parseInt(hex, 16))
      i += 5
      continue
    }
    text += { n: '\n', t: '\t', r: '', b: '', f: '' }[next] ?? next
    i += 1
  }
  return text
}

/** The question plus the text of the files the user added, marked so the model treats it as data. */
/** The question with its files: their text between tags, and photos as images the model looks at. */
export function withAttachments(request: AylaRequest): string | ContentPart[] {
  if (!request.attachments?.length) return request.text
  const files = request.attachments.map((file) => `<bijlage naam="${file.name.replaceAll('"', "'")}">\n${file.text}\n</bijlage>`)
  const text = [request.text, ...files].join('\n\n')
  const images = request.attachments.filter((file) => file.image)
  if (!images.length) return text
  return [
    { type: 'text', text: `${text}\n\nDe afbeeldingen hierbij zijn, in deze volgorde: ${images.map((f) => f.name).join(', ')}.` },
    ...images.map((file) => ({ type: 'image_url' as const, image_url: { url: `data:image/jpeg;base64,${file.image}` } })),
  ]
}

const SOURCE_NAMES: Record<Vacancy['source'], string> = { example: 'voorbeelden', adzuna: 'Adzuna', jooble: 'Jooble', web: 'internet' }

/** The conversation so far for the model, with answers that follow each other (a round of her own) as one. */
function pastMessages(history: PastMessage[]): ChatMessage[] {
  const messages: ChatMessage[] = []
  for (const turn of history) {
    const role = turn.role === 'user' ? 'user' as const : 'assistant' as const
    const last = messages.at(-1)
    if (last && last.role === role && typeof last.content === 'string') last.content = `${last.content}\n${turn.text}`
    else messages.push({ role, content: turn.text })
  }
  return messages
}

/** What the app tells Ayla after it carried out her actions. */
export function resultsMessage(results: ActionResult[]): string {
  const lines = results.map((result, index) => `${index + 1}. ${result.do}: ${result.ok ? 'gelukt' : 'niet gelukt'}${result.said ? `. ${result.said}` : ''}`)
  return `(Bericht van PAVE, niet van de gebruiker.) Dit kwam er van je acties:
${lines.join('\n')}
Ga verder met wat de gebruiker vroeg: doe de stappen die nog moeten, kies een andere weg voor wat niet lukte, of vraag de gebruiker wat je nodig hebt. Herhaal niets wat gelukt is. Is alles klaar, zeg dan in één korte zin wat er gedaan is, met actions leeg.`
}

const LIGHT = /^(hoi|hey|hallo|hi|goedemorgen|goedemiddag|goedenavond|dank ?je( wel)?|dankjewel|bedankt|thanks|top|oke|oké|ok|prima|fijn|doei|tot ziens)[\s!.]*$/i
const HARD = /\b(cv|curriculum|motivatiebrief|sollicitatiebrief|plan|stappenplan|vergelijk|analyseer|analyse|samenvat|samenvatting|herschrijf|verbeter|leg uit|waarom|voor- en nadelen|advies)\b/i
const SEVERAL = /\b(en dan|daarna|vervolgens|en ook)\b| en (zet|maak|open|verplaats|archiveer|verwijder|bewaar|noem|start)\b/i

/**
 * How much thinking this turn asks for, which picks the model: a greeting is light, real work is hard (writing or
 * comparing, files, a long or compound request, going on after her own actions), and the rest is normal.
 */
export function effortFor(request: AylaRequest, mayLook = false): Effort {
  const text = request.text.trim()
  if (request.results?.length || request.attachments?.length) return 'hard'
  if (LIGHT.test(text)) return 'light'
  if (text.length > 280 || HARD.test(text) || SEVERAL.test(text)) return 'hard'
  // A question about what fits with the vault open asks for weighing evidence.
  if (mayLook && /\b(past|passen|geschikt|sterk|zwak|mis|ontbreekt|kans)\b/i.test(text)) return 'hard'
  return 'normal'
}

/** "Wil je dat ik de vacature bewaar?", "Zal ik de map maken?" as the last thing she says. */
const ASKS_BEFORE_DOING = /\b(wil je dat ik|zal ik|moet ik|wil je dat ik dat|vind je het goed (als|dat) ik)\b[^.?!]*\?$/i

const CONFIRM_QUESTIONS: Partial<Record<ActionKind, (action: AppAction) => string>> = {
  deleteChat: () => 'Zal ik dit gesprek verwijderen?',
  deleteEvidence: (action) => `Zal ik "${action.target}" uit je kluis verwijderen? Dat kan niet ongedaan worden gemaakt.`,
  signOut: () => 'Zal ik je uitloggen?',
  forgetAll: () => 'Zal ik alles vergeten wat ik over je onthoud? Dat kan niet ongedaan worden gemaakt.',
  allowAyla: (action) => `Mag ik "${action.target}" voortaan bekijken en gebruiken?`,
}

const NEEDS_TARGET: readonly ActionKind[] = ['openFolder', 'openChat', 'moveToFolder', 'archiveEvidence', 'allowAyla', 'requestVerification', 'deleteEvidence']
const NEEDS_VALUE: readonly ActionKind[] = [
  'openSettingsPage', 'renameChat', 'pinChat', 'setChatExpiry', 'setTheme', 'setTextSize', 'setDisplayMode', 'setVaultLayout', 'setVoiceText',
  'setChatsInSearch', 'setAnimations', 'setMemory', 'createFolder', 'moveToFolder', 'allowAyla', 'openVacancy', 'saveVacancy',
]

/** The actions of an answer as the app gets them: known ones only, complete, at most 4, and only on the iPhone. */
export function cleanActions(raw: unknown, device: AylaRequest['device']): AppAction[] {
  if (device !== 'phone' || !Array.isArray(raw)) return []
  const actions: AppAction[] = []
  for (const entry of raw as Record<string, unknown>[]) {
    const kind = entry?.do as ActionKind
    if (!ACTIONS.includes(kind)) continue
    const word = (value: unknown) => (typeof value === 'string' ? value.replace(/\s+/g, ' ').trim().slice(0, 120) : '')
    const value = word(entry.value)
    const target = word(entry.target)
    if ((NEEDS_TARGET.includes(kind) && !target) || (NEEDS_VALUE.includes(kind) && !value)) continue
    actions.push({ do: kind, ...(value ? { value } : {}), ...(target ? { target } : {}), ...(needsConfirmation(kind, value) ? { confirm: true as const } : {}) })
    if (actions.length === 4) break
  }
  return actions
}

interface SearchTerms { what: string; where: string; also: string | null }

function searchStatus(terms: SearchTerms): Status {
  return { kind: 'vacancySearch', what: terms.what, where: terms.where, ...(terms.also ? { also: terms.also } : {}) }
}

/** The search itself, and a second one beside it when Ayla also looks for a related job; each vacancy once. */
async function searchTerms(searchVacancies: SearchVacancies | undefined, terms: SearchTerms): Promise<SearchResult> {
  const also = terms.also && terms.also.toLocaleLowerCase('nl') !== terms.what.toLocaleLowerCase('nl') ? [terms.also] : []
  const results = await Promise.all([terms.what, ...also].map((what) => search(searchVacancies, what, terms.where)))
  const found = results.flatMap((result) => (result.status === 'ok' ? [result.items] : []))
  return found.length ? { status: 'ok', items: mergeFound(found) } : results[0]
}

const NOT_A_COMPANY_SITE = /(^|\.)(jooble|adzuna|indeed|linkedin|glassdoor|werkzoeken|nationalevacaturebank|monsterboard|stepstone|intermediair|jobbird|werk|facebook|instagram|x|twitter|youtube|tiktok|wikipedia|google)\.[a-z.]+$/
const GENERIC_WORDS = new Set(['groep', 'group', 'nederland', 'holding', 'diensten', 'services', 'solutions', 'international', 'gemeente', 'stichting', 'bedrijf', 'company', 'consultancy', 'software', 'techniek', 'technology'])

/**
 * Whether a domain can be this company's own site, by name alone: its main label is in the company's name, or the
 * company's own word is in the label ("ogd.nl" for "OGD ict-diensten", "synseltechniek.nl" for "Synsel Techniek").
 * A site the model made up for another company does not pass.
 */
export function siteFits(domain: string, company: string): boolean {
  const site = domain.toLowerCase().trim().replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/.*$/, '')
  if (!/^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(site) || NOT_A_COMPANY_SITE.test(site) || /^via /i.test(company)) return false
  const label = site.split('.').slice(-2)[0].replace(/-/g, '')
  const letters = (text: string) => text.toLocaleLowerCase('nl').normalize('NFD').replace(/[^a-z0-9 ]/g, '')
  const name = letters(company)
  const words = name.split(' ').filter((word) => word.length >= 3 && !GENERIC_WORDS.has(word))
  if (label.length < 3 || !words.length) return false
  return name.replace(/ /g, '').includes(label) || words.some((word) => word.length >= 4 && label.includes(word)) || label === words.map((word) => word[0]).join('')
}

/** The found vacancies with a logo where the model named the company's site, the name fits and the site is there. */
export async function withLogos(found: FoundVacancy[], raw: unknown, siteExists?: (domain: string) => Promise<boolean>): Promise<FoundVacancy[]> {
  if (!siteExists || !Array.isArray(raw)) return found
  const named = new Map<number, string>()
  for (const entry of raw as Record<string, unknown>[]) {
    if (typeof entry?.vacancy !== 'number' || typeof entry.site !== 'string' || named.has(entry.vacancy)) continue
    const site = entry.site.toLowerCase().trim().replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/.*$/, '')
    const vacancy = found[entry.vacancy - 1]?.vacancy
    if (vacancy && siteFits(site, vacancy.company)) named.set(entry.vacancy, site)
  }
  // The same site once, however many vacancies of that company.
  const checks = new Map<string, Promise<boolean>>()
  const exists = (site: string) => {
    if (!checks.has(site)) checks.set(site, siteExists(site).catch(() => false))
    return checks.get(site)!
  }
  return Promise.all(found.map(async (f, index) => {
    if (f.vacancy.logoUrl) return f
    // What the model named first, then the company's own name as a site ("Synsel Techniek" is synseltechniek.nl).
    const candidates = [...new Set([named.get(index + 1), ...sitesFromName(f.vacancy.company)].filter((site): site is string => !!site))]
    const answers = await Promise.all(candidates.map(exists))
    const site = candidates.find((_, i) => answers[i])
    return site ? { ...f, vacancy: { ...f.vacancy, logoUrl: logoUrl(site) } } : f
  }))
}

/**
 * The sites a company's name itself points to, to try when the model named none: the name when it is a domain
 * ("Recruiting.ki"), and the whole name written together with .nl and .com. Never a part of the name, which could be
 * someone else's site.
 */
export function sitesFromName(company: string): string[] {
  if (/^via /i.test(company)) return []
  const name = company.toLocaleLowerCase('nl').trim()
  if (/^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(name) && !NOT_A_COMPANY_SITE.test(name)) return [name]
  const legal = new Set(['bv', 'nv', 'vof', 'holding', 'groep', 'group', 'nederland', 'netherlands', 'international', 'the'])
  const slug = name.normalize('NFD').replace(/\b(b\.?v\.?|n\.?v\.?|v\.?o\.?f\.?)(?=\s|$)/g, ' ').replace(/[^a-z0-9 ]/g, ' ').split(' ').filter((word) => word && !legal.has(word)).join('')
  return slug.length >= 4 && slug.length <= 30 ? [`${slug}.nl`, `${slug}.com`] : []
}

/** The vacancy that fits best first: more that fits, less that is missing. Vacancies without a match keep their place. */
export function bestFirst(vacancies: Vacancy[]): Vacancy[] {
  const score = (v: Vacancy) => v.matches.length * 2 - v.skillGap.length
  return vacancies.map((vacancy, index) => ({ vacancy, index })).sort((a, b) => score(b.vacancy) - score(a.vacancy) || a.index - b.index).map((entry) => entry.vacancy)
}

type SearchResult = { status: 'ok'; items: FoundVacancy[] } | { status: 'unavailable' } | { status: 'failed' }

async function search(searchVacancies: SearchVacancies | undefined, what: string, where: string): Promise<SearchResult> {
  if (!searchVacancies) return { status: 'unavailable' }
  try {
    return { status: 'ok', items: await searchVacancies(what, where) }
  } catch {
    return { status: 'failed' }
  }
}

function describeSearch(result: SearchResult, mayLook = false, consent: VaultConsent = 'notAsked'): string {
  const matching = mayLook
    ? ' Vul vacancyMatches: per vacature wat past en wat ontbreekt, met de letterlijke tekst uit die vacature waar het uit blijkt. Noem in text kort welke het best past en waarom, en het grootste gat met een concrete stap om dat te halen (een cursus, certificaat of project), als mogelijkheid en niet als garantie.'
    : consent === 'declined'
      ? ' Je mag niet in de kluis kijken, dus laat vacancyMatches leeg en vraag er niet opnieuw om.'
      : ' Je mag nog niet in de kluis kijken, dus laat vacancyMatches leeg. Zet askVault op "te laten zien welke vacatures bij je passen": PAVE vraagt dat dan onder je antwoord, en de gebruiker kan ook zelf kiezen welke gegevens je gebruikt.'
  const sites = ' Vul vacancySites voor de bedrijven waarvan je de eigen website zeker weet.'
  const rules = `Bespreek alleen wat hieronder staat en verzin niets.${sites} Het is maar een stukje van de vacaturetekst, dus zeg niet dat je alle eisen kent. Noem een vacature bij functie en bedrijf, nooit bij nummer: de kaarten kunnen in een andere volgorde staan. Zet vacancySearch op null.${matching}`
  if (result.status === 'unavailable') return `Vacatures zoeken is nog niet ingesteld. Zeg dat eerlijk en kort. Zet vacancySearch op null.`
  if (result.status === 'failed') return `Vacatures zoeken lukte nu niet. Zeg dat eerlijk en kort. Zet vacancySearch op null.`
  if (!result.items.length) return `Er zijn geen vacatures gevonden. Zeg dat en stel andere zoekwoorden voor. Zet vacancySearch op null.`
  const list = result.items.map((f, i) => {
    const v = f.vacancy
    return `${i + 1}. ${v.title} bij ${v.company}${v.city ? ` in ${v.city}` : ''}. ${f.snippet}`
  })
  const web = result.items.some((f) => f.vacancy.source === 'web')
  const from = web ? 'gevonden op internet; controleer of iets een echte vacature is en noem alleen wat hieronder staat' : `via ${SOURCE_NAMES[result.items[0].vacancy.source]}`
  return `Gevonden vacatures (${from}). De gebruiker ziet ze als kaarten onder je antwoord. ${rules}\n${list.join('\n')}`
}

const MAX_LINKS = 4

/** Lowercase with single spaces, to check that a requirement is really in the vacancy text. */
function normalized(text: string): string {
  return text.toLocaleLowerCase('nl').replace(/[‘’]/g, "'").replace(/\s+/g, ' ').trim()
}

/** The links the model gave for one vacancy, keeping only those whose requirement is a literal part of its text. */
function checkedLinks(raw: unknown, snippet: string): RequirementLink[] {
  if (!Array.isArray(raw)) return []
  const text = normalized(snippet)
  const links: RequirementLink[] = []
  for (const entry of raw as Record<string, unknown>[]) {
    const skill = typeof entry?.skill === 'string' ? entry.skill.trim().slice(0, 60) : ''
    const requirement = typeof entry?.requirement === 'string' ? entry.requirement.replace(/\s+/g, ' ').trim().replace(/^[."'“”]+|[."'“”]+$/g, '') : ''
    if (!skill || requirement.length < 3 || requirement.length > 200 || !text.includes(normalized(requirement))) continue
    if (links.some((link) => link.skill.toLocaleLowerCase('nl') === skill.toLocaleLowerCase('nl'))) continue
    links.push({ skill, requirement })
    if (links.length === MAX_LINKS) break
  }
  return links
}

/** The found vacancies with what fits and what is missing, as the model saw it in the vault and the vacancy text. */
export function withMatches(found: FoundVacancy[], raw: unknown): Vacancy[] {
  const perVacancy = new Map<number, Record<string, unknown>>()
  for (const entry of Array.isArray(raw) ? (raw as Record<string, unknown>[]) : []) {
    if (typeof entry?.vacancy === 'number' && !perVacancy.has(entry.vacancy)) perVacancy.set(entry.vacancy, entry)
  }
  return found.map((f, index) => {
    const entry = perVacancy.get(index + 1)
    if (!entry) return f.vacancy
    const matches = checkedLinks(entry.matches, f.snippet)
    const gaps = checkedLinks(entry.gaps, f.snippet).filter((gap) => !matches.some((m) => m.skill.toLocaleLowerCase('nl') === gap.skill.toLocaleLowerCase('nl')))
    return { ...f.vacancy, matches, skillGap: gaps }
  })
}

/** The search terms once the model wrote them completely; null before that. */
export function vacancySearchSoFar(content: string): SearchTerms | null {
  const found = content.match(/"vacancySearch"\s*:\s*\{\s*"what"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,\s*"where"\s*:\s*"((?:[^"\\]|\\.)*)"\s*(?:,\s*"also"\s*:\s*(?:null|"((?:[^"\\]|\\.)*)")\s*)?\}/)
  if (!found) return null
  try {
    const what = (JSON.parse(`"${found[1]}"`) as string).trim()
    const also = found[3] ? (JSON.parse(`"${found[3]}"`) as string).trim() : ''
    return what ? { what, where: (JSON.parse(`"${found[2]}"`) as string).trim(), also: also || null } : null
  } catch {
    return null
  }
}

/** A model output that already asks to look in the vault, with its text complete; null while it is not that far. */
export function consentAskSoFar(content: string): ModelOutput | null {
  const text = content.match(/"text"\s*:\s*"((?:[^"\\]|\\.)*)"/)
  const ask = content.match(/"askVault"\s*:\s*"((?:[^"\\]|\\.)*)"/)
  if (!text || !ask) return null
  try {
    const purpose = JSON.parse(`"${ask[1]}"`) as string
    if (!purpose.trim()) return null
    return { ...parseOutput('{}'), text: JSON.parse(`"${text[1]}"`) as string, askVault: purpose }
  } catch {
    return null
  }
}

function parseOutput(content: string): ModelOutput {
  try {
    const json = JSON.parse(content)
    return {
      text: typeof json.text === 'string' ? json.text : '',
      question: json.question && Array.isArray(json.question.choices) ? json.question : null,
      navigation: json.navigation && typeof json.navigation.screen === 'string' ? json.navigation : null,
      vacancySearch: json.vacancySearch && typeof json.vacancySearch.what === 'string' && json.vacancySearch.what.trim()
        ? {
          what: json.vacancySearch.what.trim(),
          where: String(json.vacancySearch.where ?? '').trim(),
          also: typeof json.vacancySearch.also === 'string' && json.vacancySearch.also.trim() ? json.vacancySearch.also.trim() : null,
        }
        : null,
      vacancyMatches: Array.isArray(json.vacancyMatches) ? json.vacancyMatches : [],
      vacancySites: Array.isArray(json.vacancySites) ? json.vacancySites : [],
      title: typeof json.title === 'string' ? json.title : null,
      memories: Array.isArray(json.memories) ? json.memories : [],
      usedMemories: Array.isArray(json.usedMemories) ? json.usedMemories : [],
      usedVaultItems: Array.isArray(json.usedVaultItems) ? json.usedVaultItems : [],
      actions: Array.isArray(json.actions) ? json.actions : [],
      continues: json.continues === true,
      vaultItem: json.vaultItem ?? null,
      askVault: typeof json.askVault === 'string' ? json.askVault : null,
    }
  } catch {
    const empty: ModelOutput = { text: '', question: null, navigation: null, vacancySearch: null, vacancyMatches: [], vacancySites: [], title: null, memories: [], usedMemories: [], usedVaultItems: [], vaultItem: null, askVault: null, actions: [], continues: false }
    // Plain words instead of JSON: that is the answer. JSON that was cut off (a long answer ran out of room) never
    // shows as it is: what was complete is kept (her text, a search she asked for), the rest is left out.
    if (!content.trimStart().startsWith('{')) return { ...empty, text: content }
    const ask = content.match(/"askVault"\s*:\s*"((?:[^"\\]|\\.)*)"/)
    let askVault: string | null = null
    try {
      askVault = ask ? JSON.parse(`"${ask[1]}"`) as string : null
    } catch {
      askVault = null
    }
    return { ...empty, text: partialText(content), vacancySearch: vacancySearchSoFar(content), askVault }
  }
}

const SAYS_SHE_SEARCHES = /\b(zoek|zoeken|kijk|bekijk|ga)\b[^.?!]*\b(vacatures?|banen|functies)\b|\b(vacatures?|banen|functies)\b[^.?!]*\b(zoek|zoeken|op zoek)\b/i

/** She says she will search for vacancies but asked for no search, and asks nothing: the user would have to ask again. */
export function announcesSearchOnly(output: { text: string; vacancySearch: unknown; question: unknown; askVault: unknown }): boolean {
  return !output.vacancySearch && !output.question && !output.askVault && SAYS_SHE_SEARCHES.test(output.text) && !output.text.trim().endsWith('?')
}

const MAX_TITLE_LENGTH = 60

/** A title the list can show in full: one line, no quotes or closing period, cut at a whole word. */
export function cleanTitle(raw: string | null | undefined): string | null {
  const title = (raw ?? '').replace(/\s+/g, ' ').trim().replace(/^["'“‘]+|["'”’.]+$/g, '').trim()
  if (title.length < 2) return null
  return shorten(title)
}

/** The first words of the first question, for a conversation that has no title from the model yet. */
export function titleFrom(text: string): string {
  return shorten(text.split('\n')[0].replace(/\s+/g, ' ').trim()) || 'Nieuw gesprek'
}

function shorten(text: string): string {
  if (text.length <= MAX_TITLE_LENGTH) return text
  const cut = text.slice(0, MAX_TITLE_LENGTH - 1)
  const space = cut.lastIndexOf(' ')
  return `${(space > 20 ? cut.slice(0, space) : cut).replace(/[,;:.!?-]+$/, '')}…`
}

const ADD_EVIDENCE_QUESTION = {
  text: 'Wil je iets toevoegen?',
  choices: [{ id: 'yes', label: 'Ja' }, { id: 'no', label: 'Nee' }],
}

/** The allowed vault item with this number in the prompt (1, 2, …), or undefined. */
function vaultItemAt(vault: AllowedVault | undefined, number: unknown) {
  if (vault?.status !== 'on' || typeof number !== 'number' || !Number.isInteger(number)) return undefined
  return vault.items[number - 1]
}

/** The kinds of the vault items the answer used, each once: what the apps show as "Uit je kluis". */
function usedData(numbers: unknown, vault: AllowedVault | undefined): Category[] {
  const kinds = (Array.isArray(numbers) ? numbers : []).map((n) => vaultItemAt(vault, n)?.kind)
  return [...new Set(kinds.filter((kind): kind is Category => CATEGORIES.includes(kind as Category)))]
}

function toReply(output: ModelOutput, blocks: Block[], conversationId: string, id: string, vault?: AllowedVault): AylaReply {
  const reply: AylaReply = {
    version: 1,
    id,
    conversationId,
    text: stripMarkdown(output.text) || FALLBACK_TEXT,
    blocks,
    usedData: usedData(output.usedVaultItems, vault),
  }
  const choices = (output.question?.choices ?? [])
    .filter((c) => typeof c?.label === 'string' && c.label.trim())
    .slice(0, 3)
    .map((c, i) => ({ id: typeof c.id === 'string' && c.id.trim() ? c.id.trim() : `choice_${i + 1}`, label: c.label.trim() }))
  if (output.question && choices.length >= 2) reply.question = { text: output.question.text ?? '', choices }
  const screen = output.navigation?.screen as Screen
  if (SCREENS.includes(screen) && NAVIGABLE.has(screen)) reply.navigation = { screen }
  // Opening one item from the vault: only an item the user allowed, by its id; otherwise the vault itself.
  if (screen === 'vaultItem') {
    const item = vaultItemAt(vault, output.navigation?.item)
    reply.navigation = item ? { screen: 'vaultItem', itemId: item.id } : { screen: 'vault' }
  }
  // Offering to add evidence is always a Ja/Nee question (Figma "Wil je iets toevoegen?"), also when the model forgot it.
  // After an open question of her own ("Wat wil je toevoegen?") the user answers in words: the conversation goes on.
  if (reply.navigation?.screen === 'addEvidence' && !reply.question) {
    if (endsWithOpenQuestion(reply.text)) delete reply.navigation
    else reply.question = ADD_EVIDENCE_QUESTION
  }
  return reply
}

function stripMarkdown(text: string): string {
  return text.replace(/\*\*|__/g, '').replace(/^#{1,6}\s+/gm, '').trim()
}
