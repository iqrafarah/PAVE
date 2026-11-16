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
  return { vacancy, snippet: plain(r.description).slice(0, 500) }
}

function plain(value: unknown): string {
  return typeof value === 'string' ? value.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim() : ''
}
