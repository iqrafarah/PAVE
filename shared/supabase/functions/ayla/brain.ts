import { type AylaReply, type AylaRequest, type Block, type Screen, SCREENS } from './contract.ts'
import { cleanMemories, type Memory, type MemorySuggestion, usedNotes } from './memory.ts'
import type { ChatMessage, Complete } from './openrouter.ts'
import { buildSystemPrompt } from './prompt.ts'
import type { FoundVacancy, SearchVacancies } from './vacancies.ts'

export interface PastMessage { role: 'user' | 'ayla'; text: string }

export interface BrainInput {
  request: AylaRequest
  conversationId: string
  history: PastMessage[]
  firstName?: string
  /** What the user let Ayla remember. Missing means Ayla remembers nothing. */
  memory?: Memory
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
const NAVIGABLE = new Set<Screen>(['home', 'vault', 'addEvidence', 'plans', 'vacancies', 'profile', 'settings'])
const FALLBACK_TEXT = 'Sorry, dat lukte me even niet. Wil je het nog een keer vragen?'

interface ModelOutput {
  text: string
  question: { text: string; choices: { id: string; label: string }[] } | null
  navigation: { screen: string } | null
  vacancySearch: { what: string; where: string } | null
  title: string | null
  memories: unknown
  usedMemories: unknown
}

/** One turn of the conversation: the prompt in layers, the model, and a reply in the contract format. */
export async function answer(input: BrainInput, deps: BrainDeps): Promise<AylaReply> {
  const { request } = input
  const memory: Memory = input.memory ?? { status: 'unavailable' }
  const messages: ChatMessage[] = [
    { role: 'system', content: buildSystemPrompt({ device: request.device, input: request.input, firstName: input.firstName, context: request.context, memory }) },
    ...input.history.slice(-HISTORY_LIMIT).map((m): ChatMessage => ({ role: m.role === 'user' ? 'user' : 'assistant', content: m.text })),
    { role: 'user', content: withAttachments(request) },
  ]

  let output = parseOutput((await deps.complete(messages)).content)
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
    output = parseOutput((await deps.complete(messages)).content)
    if (found.status === 'ok' && found.items.length && request.device !== 'watch') {
      blocks.push({ type: 'vacancies', items: found.items.map((f) => f.vacancy) })
    }
  }

  const reply = toReply(output, blocks, input.conversationId, deps.newId())
  const later = cleanMemories(output.memories, memory)
  const suggestions: MemorySuggestion[] = later.length ? later : heard
  if (suggestions.length) reply.memories = suggestions
  const laterUsed = usedNotes(output.usedMemories, memory)
  const used = laterUsed.length ? laterUsed : firstUsed
  if (used.length) reply.usedMemories = used
  return reply
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
    }
  } catch {
    return { text: content, question: null, navigation: null, vacancySearch: null, title: null, memories: [], usedMemories: [] }
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

function toReply(output: ModelOutput, blocks: Block[], conversationId: string, id: string): AylaReply {
  const reply: AylaReply = {
    version: 1,
    id,
    conversationId,
    text: stripMarkdown(output.text) || FALLBACK_TEXT,
    blocks,
    usedData: [],
  }
  const choices = (output.question?.choices ?? [])
    .filter((c) => typeof c?.label === 'string' && c.label.trim())
    .slice(0, 3)
    .map((c, i) => ({ id: typeof c.id === 'string' && c.id.trim() ? c.id.trim() : `choice_${i + 1}`, label: c.label.trim() }))
  if (output.question && choices.length >= 2) reply.question = { text: output.question.text ?? '', choices }
  const screen = output.navigation?.screen as Screen
  if (SCREENS.includes(screen) && NAVIGABLE.has(screen)) reply.navigation = { screen }
  return reply
}

function stripMarkdown(text: string): string {
  return text.replace(/\*\*|__/g, '').replace(/^#{1,6}\s+/gm, '').trim()
}
