import { type AylaReply, type AylaRequest, type Block, CATEGORIES, type Category, type Screen, SCREENS } from './contract.ts'
import type { AllowedVault } from './vault.ts'
import { cleanPurpose, CONSENT_QUESTION_CHOICES, consentQuestion, mayLookInVault, vaultConsent } from './consent.ts'
import { cleanMemories, type Memory, type MemorySuggestion, usedNotes } from './memory.ts'
import type { ChatMessage, Complete } from './openrouter.ts'
import { buildSystemPrompt } from './prompt.ts'
import { vaultProposal } from './proposal.ts'
import type { FoundVacancy, SearchVacancies } from './vacancies.ts'

/** A message so far. An Ayla turn says whether it asked to look in the vault, for the consent of this conversation. */
export interface PastMessage { role: 'user' | 'ayla'; text: string; askedVault?: boolean }

export interface BrainInput {
  request: AylaRequest
  conversationId: string
  history: PastMessage[]
  firstName?: string
  /** What the user let Ayla remember. Missing means Ayla remembers nothing. */
  memory?: Memory
  /** The vault items the user allowed Ayla to use. Missing means she sees none. She only sees them once the user said
   * Ja to looking in the vault in this conversation (see consent.ts). */
  vault?: AllowedVault
  /** Called with the text of the answer so far, while the model writes it. */
  onText?: (text: string) => void
  /** Stops the answer, for instance when the user taps stop. */
  signal?: AbortSignal
  /** Called with a short title for a new conversation, when the model gives one. */
  onTitle?: (title: string) => void
}

export interface BrainDeps {
  complete: Complete
  /** Missing when no Adzuna key is configured. */
  searchVacancies?: SearchVacancies
  newId: () => string
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
  const asked = message.role === 'ayla' && !!message.reply?.accessRequest
  if (!asked) return { role: message.role, text: message.text }
  const question = message.reply?.question?.text
  return { role: 'ayla', text: question ? `${message.text}\n${question}` : message.text, askedVault: true }
}
const NAVIGABLE = new Set<Screen>(['home', 'vault', 'addEvidence', 'plans', 'vacancies', 'profile', 'settings'])
const FALLBACK_TEXT = 'Sorry, dat lukte me even niet. Wil je het nog een keer vragen?'

interface ModelOutput {
  text: string
  question: { text: string; choices: { id: string; label: string }[] } | null
  navigation: { screen: string; item?: number | null } | null
  vacancySearch: { what: string; where: string } | null
  title: string | null
  memories: unknown
  usedMemories: unknown
  usedVaultItems: unknown
  vaultItem: unknown
  askVault: unknown
}

/** One turn of the conversation: the prompt in layers, the model, and a reply in the contract format. */
export async function answer(input: BrainInput, deps: BrainDeps): Promise<AylaReply> {
  const { request } = input
  const memory: Memory = input.memory ?? { status: 'unavailable' }
  const consent = vaultConsent(input.history, request)
  const mayLook = mayLookInVault(consent)
  const vault = mayLook ? input.vault : undefined
  const messages: ChatMessage[] = [
    { role: 'system', content: buildSystemPrompt({ device: request.device, input: request.input, firstName: input.firstName, context: request.context, memory, vault, vaultConsent: consent }) },
    ...input.history.slice(-HISTORY_LIMIT).map((m): ChatMessage => ({ role: m.role === 'user' ? 'user' : 'assistant', content: m.text })),
    { role: 'user', content: withAttachments(request) },
  ]

  let lastText = ''
  const options = {
    signal: input.signal,
    onContent: input.onText
      ? (content: string) => {
        const text = stripMarkdown(partialText(content))
        if (text && text !== lastText) {
          lastText = text
          input.onText?.(text)
        }
      }
      : undefined,
  }
  let output = parseOutput((await deps.complete(messages, options)).content)
  // The first answer heard what the user said; the second one only talks about the vacancies.
  const heard = cleanMemories(output.memories, memory)
  const firstUsed = usedNotes(output.usedMemories, memory)
  const title = cleanTitle(output.title)
  if (title && input.onTitle) input.onTitle(title)
  const blocks: Block[] = []

  if (output.vacancySearch) {
    const { what, where } = output.vacancySearch
    const found = await search(deps.searchVacancies, what, where)
    messages.push({ role: 'assistant', content: JSON.stringify(output) }, { role: 'system', content: describeSearch(found) })
    output = parseOutput((await deps.complete(messages, options)).content)
    if (found.status === 'ok' && found.items.length && request.device !== 'watch') {
      blocks.push({ type: 'vacancies', items: found.items.map((f) => f.vacancy) })
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
  // Ayla wants to look in the vault and may not yet: the app asks, with fixed words, before she sees anything.
  const purpose = mayLook ? null : cleanPurpose(output.askVault)
  if (purpose) {
    reply.accessRequest = { id: deps.newId(), purpose, categories: [] }
    reply.question = { text: consentQuestion(purpose), choices: CONSENT_QUESTION_CHOICES }
    delete reply.navigation
  }
  return reply
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
export function withAttachments(request: AylaRequest): string {
  if (!request.attachments?.length) return request.text
  const files = request.attachments.map((file) => `<bijlage naam="${file.name.replaceAll('"', "'")}">\n${file.text}\n</bijlage>`)
  return [request.text, ...files].join('\n\n')
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

function describeSearch(result: SearchResult): string {
  const rules = 'Bespreek alleen wat hieronder staat en verzin niets. Het is maar een stukje van de vacaturetekst, dus zeg niet dat je alle eisen kent. Zet vacancySearch op null.'
  if (result.status === 'unavailable') return `Vacatures zoeken is nog niet ingesteld. Zeg dat eerlijk en kort. Zet vacancySearch op null.`
  if (result.status === 'failed') return `Vacatures zoeken lukte nu niet. Zeg dat eerlijk en kort. Zet vacancySearch op null.`
  if (!result.items.length) return `Er zijn geen vacatures gevonden. Zeg dat en stel andere zoekwoorden voor. Zet vacancySearch op null.`
  const list = result.items.map((f, i) => {
    const v = f.vacancy
    return `${i + 1}. ${v.title} bij ${v.company}${v.city ? ` in ${v.city}` : ''}. ${f.snippet}`
  })
  return `Gevonden vacatures (Adzuna). De gebruiker ziet ze als kaarten onder je antwoord. ${rules}\n${list.join('\n')}`
}

function parseOutput(content: string): ModelOutput {
  try {
    const json = JSON.parse(content)
    return {
      text: typeof json.text === 'string' ? json.text : '',
      question: json.question && Array.isArray(json.question.choices) ? json.question : null,
      navigation: json.navigation && typeof json.navigation.screen === 'string' ? json.navigation : null,
      vacancySearch: json.vacancySearch && typeof json.vacancySearch.what === 'string' && json.vacancySearch.what.trim()
        ? { what: json.vacancySearch.what.trim(), where: String(json.vacancySearch.where ?? '').trim() }
        : null,
      title: typeof json.title === 'string' ? json.title : null,
      memories: Array.isArray(json.memories) ? json.memories : [],
      usedMemories: Array.isArray(json.usedMemories) ? json.usedMemories : [],
      usedVaultItems: Array.isArray(json.usedVaultItems) ? json.usedVaultItems : [],
      vaultItem: json.vaultItem ?? null,
      askVault: typeof json.askVault === 'string' ? json.askVault : null,
    }
  } catch {
    return { text: content, question: null, navigation: null, vacancySearch: null, title: null, memories: [], usedMemories: [], usedVaultItems: [], vaultItem: null, askVault: null }
  }
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
  if (reply.navigation?.screen === 'addEvidence' && !reply.question) reply.question = ADD_EVIDENCE_QUESTION
  return reply
}

function stripMarkdown(text: string): string {
  return text.replace(/\*\*|__/g, '').replace(/^#{1,6}\s+/gm, '').trim()
}
