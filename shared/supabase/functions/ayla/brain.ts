import { type AylaReply, type AylaRequest, type Block, type Screen, SCREENS } from './contract.ts'
import type { ChatMessage, Complete } from './openrouter.ts'
import { buildSystemPrompt } from './prompt.ts'
import type { FoundVacancy, SearchVacancies } from './vacancies.ts'

export interface PastMessage { role: 'user' | 'ayla'; text: string }

export interface BrainInput {
  request: AylaRequest
  conversationId: string
  history: PastMessage[]
  firstName?: string
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
}

/** One turn of the conversation: the prompt in layers, the model, and a reply in the contract format. */
export async function answer(input: BrainInput, deps: BrainDeps): Promise<AylaReply> {
  const { request } = input
  const messages: ChatMessage[] = [
    { role: 'system', content: buildSystemPrompt({ device: request.device, firstName: input.firstName, context: request.context }) },
    ...input.history.slice(-HISTORY_LIMIT).map((m): ChatMessage => ({ role: m.role === 'user' ? 'user' : 'assistant', content: m.text })),
    { role: 'user', content: request.text },
  ]

  let output = parseOutput((await deps.complete(messages)).content)
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

  return toReply(output, blocks, input.conversationId, deps.newId())
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
    }
  } catch {
    return { text: content, question: null, navigation: null, vacancySearch: null }
  }
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
