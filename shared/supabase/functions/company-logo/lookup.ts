// The logo of a company on a vacancy card that came without one. Its own website is found by its name, or else by a
// web search for the name and place; then the sharpest square logo on that site is picked, as for evidence in the
// vault. Only the company's name and place go out, which are public; nothing about the user.
import { type Fetch, findLogo } from '../ayla-evidence/logo.ts'
import { siteFits, sitesFromName } from '../ayla/brain.ts'
import { PROVIDER, SMALL } from '../ayla/openrouter.ts'

export const MAX_NAME_LENGTH = 200

export interface CompanyLogo { url: string; site: string }

/** Finds the domain of a company's own site, or undefined. */
export type SiteSearch = (company: string, city?: string) => Promise<string | undefined>

const SEARCH_PROMPT = `
Je zoekt het domein van de officiële website van een bedrijf of organisatie in Nederland, zoals "ogd.nl".
Gebruik alleen de zoekresultaten. Nooit een vacaturesite, sociale media, een bedrijvengids of een nieuwssite.
Weet je het niet zeker, geef dan null. Antwoord alleen met JSON: {"site":"voorbeeld.nl"} of {"site":null}.
`.trim()

/** A name and place worth looking up: a real company, not "Via werkzoeken.nl". */
export function lookupProblem(company: unknown, city: unknown): string | null {
  if (typeof company !== 'string' || !company.trim() || company.length > MAX_NAME_LENGTH || /^via /i.test(company.trim())) return 'invalid_request'
  if (city !== undefined && city !== null && (typeof city !== 'string' || city.length > MAX_NAME_LENGTH)) return 'invalid_request'
  return null
}

/** "https://www.ogd.nl/vacatures" and "OGD.nl" both to "ogd.nl". */
export function bareDomain(raw: unknown): string | undefined {
  if (typeof raw !== 'string') return undefined
  const site = raw.toLowerCase().trim().replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/[/?#].*$/, '')
  return /^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(site) ? site : undefined
}

/** The company's own site and its logo: by name first, then by search; only a site whose name fits the company. */
export async function companyLogo(company: string, city: string | undefined, searchSite: SiteSearch, fetchImpl: Fetch = fetch): Promise<CompanyLogo | undefined> {
  for (const site of sitesFromName(company)) {
    const logo = await findLogo(site, fetchImpl)
    if (logo?.url) return { url: logo.url, site }
  }
  const found = bareDomain(await searchSite(company, city).catch(() => undefined))
  if (!found || !siteFits(found, company)) return undefined
  const logo = await findLogo(found, fetchImpl)
  return logo?.url ? { url: logo.url, site: found } : undefined
}

/**
 * The model answers from a web search. Pages about a company are often on other sites, so the named site need not be
 * among the results: `companyLogo` only takes it when its name fits the company and it has a logo.
 */
export function webSiteSearch(apiKey: string, fetchImpl: Fetch = fetch): SiteSearch {
  return async (company, city) => {
    const response = await fetchImpl('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: SMALL,
        provider: PROVIDER,
        temperature: 0,
        max_tokens: 60,
        plugins: [{ id: 'web', engine: 'exa', max_results: 3 }],
        messages: [
          { role: 'system', content: SEARCH_PROMPT },
          { role: 'user', content: `Bedrijf: ${company}${city ? `, ${city}` : ''}` },
        ],
      }),
      signal: AbortSignal.timeout(12_000),
    })
    if (!response.ok) return undefined
    const message = (await response.json().catch(() => null))?.choices?.[0]?.message
    return siteFromAnswer(message?.content)
  }
}

/** The site the model named, as a bare domain. */
export function siteFromAnswer(content: unknown): string | undefined {
  if (typeof content !== 'string') return undefined
  try {
    return bareDomain(JSON.parse(content.match(/\{[\s\S]*\}/)?.[0] ?? 'null')?.site)
  } catch {
    return undefined
  }
}
