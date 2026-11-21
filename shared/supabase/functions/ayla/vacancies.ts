import type { Vacancy } from './contract.ts'

export interface FoundVacancy {
  vacancy: Vacancy
  /** A short piece of the vacancy text. Adzuna only gives a snippet, never the whole text. */
  snippet: string
}

export type SearchVacancies = (what: string, where: string) => Promise<FoundVacancy[]>

const RESULTS = 5

/** Searches Dutch vacancies through the Adzuna API. Only the search terms leave PAVE. */
export function adzunaSearch(appId: string, appKey: string, fetchImpl: typeof fetch = fetch): SearchVacancies {
  return async (what, where) => {
    const url = new URL('https://api.adzuna.com/v1/api/jobs/nl/search/1')
    url.searchParams.set('app_id', appId)
    url.searchParams.set('app_key', appKey)
    url.searchParams.set('results_per_page', String(RESULTS))
    url.searchParams.set('what', what)
    if (where.trim()) url.searchParams.set('where', where)
    url.searchParams.set('content-type', 'application/json')

    const response = await fetchImpl(url, { headers: { Accept: 'application/json' } })
    if (!response.ok) throw new Error(`Adzuna answered ${response.status}`)
    const json = await response.json()
    const results: unknown[] = Array.isArray(json?.results) ? json.results : []
    return results.map(toFoundVacancy).filter((found): found is FoundVacancy => found !== null)
  }
}

export function toFoundVacancy(raw: unknown): FoundVacancy | null {
  const r = raw as Record<string, any>
  const title = plain(r?.title)
  const company = plain(r?.company?.display_name)
  if (r?.id === undefined || !title || !company) return null

  const vacancy: Vacancy = { id: `adzuna_${r.id}`, title, company, source: 'adzuna', matches: [], skillGap: [] }
  const city = plain(r.location?.display_name)
  if (city) vacancy.city = city
  if (r.contract_time === 'full_time') vacancy.employment = 'fullTime'
  if (r.contract_time === 'part_time') vacancy.employment = 'partTime'
  const min = Number(r.salary_min)
  const max = Number(r.salary_max)
  if (Number.isFinite(min) && Number.isFinite(max) && min > 0 && max > 0) {
    vacancy.salary = {
      min: Math.min(min, max),
      max: Math.max(min, max),
      period: 'year',
      currency: 'EUR',
      isEstimate: String(r.salary_is_predicted) === '1',
    }
  }
  if (typeof r.redirect_url === 'string' && r.redirect_url.startsWith('https://')) vacancy.url = r.redirect_url
  const snippet = plain(r.description).slice(0, 500)
  if (snippet) vacancy.summary = snippet
  return { vacancy, snippet }
}

const ENTITIES: Record<string, string> = { nbsp: ' ', amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", euro: '€', '#39': "'" }

function plain(value: unknown): string {
  if (typeof value !== 'string') return ''
  return value
    .replace(/<\/?(?:b|i|u|em|strong|span|a|mark)\b[^>]*>/gi, '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&(#?\w+);/g, (whole, name: string) => ENTITIES[name.toLowerCase()] ?? (name.startsWith('#') ? String.fromCharCode(Number(name.slice(1))) : whole))
    .replace(/\s+/g, ' ')
    .trim()
}

/** The address the apps load a logo from: the icon of a site, as large as the service has it. */
export function logoUrl(domain: string): string {
  return `https://www.google.com/s2/favicons?domain=${encodeURIComponent(domain)}&sz=256`
}

/** Whether a site answers, quickly: a logo is not worth waiting long for. Only the domain leaves PAVE. */
export function siteChecker(fetchImpl: typeof fetch = fetch, timeoutMs = 2000): (domain: string) => Promise<boolean> {
  return async (domain) => {
    try {
      const response = await fetchImpl(`https://${domain}/`, { method: 'HEAD', redirect: 'follow', signal: AbortSignal.timeout(timeoutMs), headers: { 'User-Agent': 'Mozilla/5.0 (compatible; PAVE)' } })
      // Some sites refuse HEAD or a visitor they do not know: they are there all the same.
      return response.status < 400 || response.status === 403 || response.status === 405
    } catch {
      return false
    }
  }
}

/** As many cards as a reply shows. */
export const MAX_VACANCIES = 6

const sameAs = (v: Vacancy) => `${v.title}|${v.company.replace(/^via /i, '')}`.toLocaleLowerCase('nl').replace(/[^a-z0-9|]+/g, ' ').trim()

/** Lists in turn (first of each, second of each), each vacancy once; a second find only brings its longer text. */
export function mergeFound(lists: FoundVacancy[][], max = MAX_VACANCIES): FoundVacancy[] {
  const merged: FoundVacancy[] = []
  const place = new Map<string, number>()
  const longest = Math.max(0, ...lists.map((list) => list.length))
  for (let i = 0; i < longest; i++) {
    for (const list of lists) {
      const found = list[i]
      if (!found) continue
      const at = place.get(sameAs(found.vacancy))
      if (at === undefined) {
        if (merged.length >= max) continue
        place.set(sameAs(found.vacancy), merged.length)
        merged.push(found)
      } else if (found.snippet.length > merged[at].snippet.length) {
        merged[at] = { vacancy: { ...merged[at].vacancy, summary: found.snippet }, snippet: found.snippet }
      }
    }
  }
  return merged
}

/**
 * A job API with the web search beside it: the API's vacancies first, the web's after them, and a vacancy both found
 * keeps the longer piece of text. The web gets a moment after the API answered; when the API finds nothing or fails,
 * the web is the source.
 */
export function withSupport(primary: SearchVacancies | undefined, support: SearchVacancies, waitMs = 6000): SearchVacancies {
  if (!primary) return support
  return async (what, where) => {
    let supportFailed = false
    const extra = support(what, where).catch(() => {
      supportFailed = true
      return [] as FoundVacancy[]
    })
    let main: FoundVacancy[] = []
    let mainFailed = false
    try {
      main = await primary(what, where)
    } catch {
      mainFailed = true
    }
    if (!main.length) {
      const found = await extra
      if (mainFailed && supportFailed) throw new Error('every source failed')
      return found
    }
    let timer: ReturnType<typeof setTimeout> | undefined
    const late = await Promise.race([extra, new Promise<FoundVacancy[]>((resolve) => { timer = setTimeout(() => resolve([]), waitMs) })])
    clearTimeout(timer)
    const merged = mergeFound([main])
    const place = new Map(merged.map((found, index) => [sameAs(found.vacancy), index]))
    for (const found of late) {
      const at = place.get(sameAs(found.vacancy))
      if (at !== undefined) {
        if (found.snippet.length > merged[at].snippet.length) merged[at] = { vacancy: { ...merged[at].vacancy, summary: found.snippet }, snippet: found.snippet }
      } else if (merged.length < MAX_VACANCIES) {
        place.set(sameAs(found.vacancy), merged.length)
        merged.push(found)
      }
    }
    return merged
  }
}

/** Tries each source in turn: the next one when a source fails or finds nothing. */
export function firstThatFinds(sources: SearchVacancies[]): SearchVacancies | undefined {
  if (!sources.length) return undefined
  return async (what, where) => {
    let failed = 0
    for (const source of sources) {
      try {
        const found = await source(what, where)
        if (found.length) return found
      } catch {
        failed++
      }
    }
    if (failed === sources.length) throw new Error('every source failed')
    return []
  }
}

/** Jooble: Dutch vacancies through its REST API (key from jooble.org/api/about). Only the search terms leave PAVE. */
export function joobleSearch(key: string, host = 'nl.jooble.org', fetchImpl: typeof fetch = fetch): SearchVacancies {
  return async (what, where) => {
    const response = await fetchImpl(`https://${host}/api/${encodeURIComponent(key)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ keywords: what, location: where, page: '1', ResultOnPage: String(RESULTS) }),
      signal: AbortSignal.timeout(10_000),
    })
    if (!response.ok) throw new Error(`Jooble answered ${response.status}`)
    const json = await response.json()
    const jobs: unknown[] = Array.isArray(json?.jobs) ? json.jobs : []
    return jobs.map(toJoobleVacancy).filter((found): found is FoundVacancy => found !== null).slice(0, RESULTS)
  }
}

export function toJoobleVacancy(raw: unknown): FoundVacancy | null {
  const r = raw as Record<string, any>
  const title = plain(r?.title)
  // Without a company, the job site it came from, so that site is never shown as the employer.
  const site = plain(r?.source).toLowerCase()
  const company = plain(r?.company) || (site ? `Via ${plain(r?.source)}` : '')
  if (r?.id === undefined || r?.id === null || !title || !company) return null
  const vacancy: Vacancy = { id: `jooble_${r.id}`, title, company, source: 'jooble', matches: [], skillGap: [] }
  const city = plain(r.location)
  if (city) vacancy.city = city
  const type = plain(r.type).toLowerCase()
  if (/full|voltijd|fulltime/.test(type)) vacancy.employment = 'fullTime'
  else if (/part|deeltijd|parttime/.test(type)) vacancy.employment = 'partTime'
  const salary = salaryFrom(plain(r.salary))
  if (salary) vacancy.salary = salary
  if (typeof r.link === 'string' && r.link.startsWith('https://')) vacancy.url = r.link
  const snippet = plain(r.snippet).replace(/^\.{3}\s*|\s*\.{3}$/g, '').slice(0, 500)
  if (snippet) vacancy.summary = snippet
  // "Via werkzoeken.nl" shows that site's own icon: it is what the card names, and no guess.
  if (!plain(r?.company) && /^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(site)) vacancy.logoUrl = logoUrl(site)
  const day = typeof r.updated === 'string' ? r.updated.match(/^\d{4}-\d{2}-\d{2}/)?.[0] : undefined
  if (day) vacancy.postedAt = day
  return { vacancy, snippet }
}

/** "€ 3.000 - € 4.000 per maand" to a range per month or year; nil when it is per hour or unclear. */
export function salaryFrom(text: string): Vacancy['salary'] | undefined {
  const period = /maand|month|p\/m|pm\b/i.test(text) ? 'month' : /jaar|year|p\/j|annual/i.test(text) ? 'year' : null
  if (!period) return undefined
  const numbers = [...text.matchAll(/(\d{1,3}(?:[.\s]\d{3})+|\d+)(?:,\d+)?\s*(k)?/gi)]
    .map((m) => Number(m[1].replace(/[.\s]/g, '')) * (m[2] ? 1000 : 1))
    .filter((n) => n >= 100)
  if (!numbers.length) return undefined
  const min = Math.min(...numbers)
  const max = Math.max(...numbers)
  return { min, max, period, currency: 'EUR', isEstimate: false }
}

/** Dutch job sites, so a web search finds single vacancies and not articles about jobs. */
export const JOB_SITES = [
  'nationalevacaturebank.nl', 'werkzoeken.nl', 'indeed.nl', 'nl.indeed.com', 'jobbird.com', 'monsterboard.nl',
  'intermediair.nl', 'stepstone.nl', 'werk.nl', 'glassdoor.nl', 'linkedin.com/jobs', 'youngcapital.nl', 'randstad.nl', 'yacht.nl',
]

/**
 * Searches the web through OpenRouter (Exa) when no job API is available. Only pages the search really returned count:
 * a vacancy whose link is not among the search results is dropped, so the model cannot invent one.
 */
export function webSearch(apiKey: string, fetchImpl: typeof fetch = fetch, model = 'mistralai/mistral-medium-3.1'): SearchVacancies {
  return async (what, where) => {
    const response = await fetchImpl('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        temperature: 0,
        max_tokens: 1200,
        plugins: [{ id: 'web', engine: 'exa', max_results: 10, include_domains: JOB_SITES }],
        messages: [
          {
            role: 'system',
            content: 'Je zoekt actuele vacatures in Nederland. Gebruik alleen de zoekresultaten. Neem alleen pagina\'s van één vacature, geen overzichten of artikelen. Neem de url exact over. Antwoord alleen met JSON: {"vacancies":[{"url":"","title":"","company":"","city":null,"employment":null}]}. employment is "fullTime", "partTime" of null. Geen tekst eromheen.',
          },
          { role: 'user', content: `Vacatures voor: ${what}${where ? ` in of rond ${where}` : ''}` },
        ],
      }),
      signal: AbortSignal.timeout(25_000),
    })
    if (!response.ok) throw new Error(`web search answered ${response.status}`)
    const json = await response.json()
    const message = json?.choices?.[0]?.message
    const citations = (Array.isArray(message?.annotations) ? message.annotations : [])
      .filter((a: any) => a?.type === 'url_citation' && a.url_citation)
      .map((a: any) => a.url_citation as { url?: string; title?: string; content?: string })
    return fromWebAnswer(typeof message?.content === 'string' ? message.content : '', citations)
  }
}

export function fromWebAnswer(content: string, citations: { url?: string; title?: string; content?: string }[]): FoundVacancy[] {
  const key = (url: string) => url.replace(/^https?:\/\/(www\.)?/i, '').replace(/[?#].*$/, '').replace(/\/$/, '').toLowerCase()
  const byUrl = new Map(citations.filter((c) => typeof c.url === 'string' && c.url.startsWith('https://')).map((c) => [key(c.url!), c]))
  let listed: Record<string, unknown>[] = []
  try {
    const start = content.indexOf('{')
    const parsed = JSON.parse(content.slice(start, content.lastIndexOf('}') + 1))
    listed = Array.isArray(parsed?.vacancies) ? parsed.vacancies : []
  } catch {
    return []
  }
  const seen = new Set<string>()
  const found: FoundVacancy[] = []
  for (const item of listed) {
    const url = typeof item?.url === 'string' ? item.url : ''
    const source = byUrl.get(key(url))
    if (!source || seen.has(key(url))) continue
    const title = plain(item.title) || plain(source.title)
    const company = plain(item.company)
    if (!title || !company) continue
    seen.add(key(url))
    const vacancy: Vacancy = { id: `web_${hash(key(url))}`, title: title.slice(0, 200), company: company.slice(0, 200), source: 'web', url: source.url, matches: [], skillGap: [] }
    const city = plain(item.city)
    if (city) vacancy.city = city.slice(0, 200)
    if (item.employment === 'fullTime' || item.employment === 'partTime') vacancy.employment = item.employment
    const snippet = plain(source.content).replace(/\[\.\.\.\]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 500)
    if (snippet) vacancy.summary = snippet
    found.push({ vacancy, snippet })
    if (found.length === RESULTS) break
  }
  return found
}

function hash(text: string): string {
  let h = 2166136261
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619)
  return (h >>> 0).toString(36)
}
