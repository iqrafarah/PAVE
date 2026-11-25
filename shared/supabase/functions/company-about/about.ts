// What a job seeker wants to know about a company before applying, found on the web: what it does, how big it is,
// where it works, and at most three facts that matter for applying (a traineeship, training, hybrid work). Only from
// the search results, each with its source; whatever the model is not sure of stays out. Only the company's name and
// place go out, which are public; nothing about the user.
import type { Fetch } from '../ayla-evidence/logo.ts'
import { lookupProblem } from '../company-logo/lookup.ts'
import { PROVIDER, SMALL } from '../ayla/openrouter.ts'

export { lookupProblem }

export interface Source { title: string; url: string }
export interface Fact { label: string; text: string }
export interface CompanyAbout {
  about: string
  sector?: string
  size?: string
  locations: string[]
  website?: string
  facts: Fact[]
  sources: Source[]
}

export const PROMPT = `
Je helpt iemand die gaat solliciteren. Zoek uit wat echt waardevol is om te weten over het genoemde bedrijf in
Nederland, en antwoord alleen met JSON in deze vorm:
{"about":"…","sector":"…","size":"…","locations":["…"],"website":"…","facts":[{"label":"…","text":"…"}]}

- "about": één of twee korte zinnen in gewoon Nederlands over wat het bedrijf doet. Geen reclametaal.
- "sector": een paar woorden, of null.
- "size": alleen als de bron het zegt, zoals "ongeveer 200 medewerkers", anders null.
- "locations": plaatsen in Nederland waar het bedrijf zit, hoogstens drie.
- "website": het domein van de eigen website, zoals "voorbeeld.nl", of null.
- "facts": hoogstens drie dingen die ertoe doen voor een sollicitant, zoals een traineeship, opleidingsbudget,
  thuiswerken of de cao. "label" is twee of drie woorden, "text" één korte zin.

Gebruik alleen wat in de zoekresultaten staat. Geen meningen, beoordelingen, salarissen of geruchten. Weet je iets niet
zeker, laat het dan weg. Vind je het bedrijf niet, antwoord dan {"about":null}.
`.trim()

const MAX = { about: 320, short: 80, fact: 200, facts: 3, locations: 3, sources: 4 }

const text = (value: unknown, max: number): string | undefined => {
  if (typeof value !== 'string') return undefined
  const trimmed = value.replace(/\s+/g, ' ').trim()
  return trimmed && trimmed.toLowerCase() !== 'null' ? trimmed.slice(0, max) : undefined
}

/** "https://www.kade.nl/over" to "kade.nl"; anything that is not a domain to undefined. */
export function domain(raw: unknown): string | undefined {
  if (typeof raw !== 'string') return undefined
  const site = raw.toLowerCase().trim().replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/[/?#].*$/, '')
  return /^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(site) ? site : undefined
}

/** The model's answer, checked and cut to size, with the sources the search gave; undefined when nothing was found. */
export function aboutFromAnswer(content: unknown, annotations: unknown): CompanyAbout | undefined {
  if (typeof content !== 'string') return undefined
  let raw: Record<string, unknown>
  try {
    raw = JSON.parse(content.match(/\{[\s\S]*\}/)?.[0] ?? 'null')
  } catch {
    return undefined
  }
  const about = text(raw?.about, MAX.about)
  if (!about) return undefined
  const facts = Array.isArray(raw.facts)
    ? raw.facts
      .map((fact: { label?: unknown; text?: unknown }) => ({ label: text(fact?.label, MAX.short), text: text(fact?.text, MAX.fact) }))
      .filter((fact): fact is Fact => !!fact.label && !!fact.text)
      .slice(0, MAX.facts)
    : []
  const locations = Array.isArray(raw.locations)
    ? raw.locations.map((place) => text(place, MAX.short)).filter((place): place is string => !!place).slice(0, MAX.locations)
    : []
  const sources = sourcesFrom(annotations)
  // Without a single source there is nothing to check it against: then it is not shown.
  if (sources.length === 0) return undefined
  return {
    about,
    sector: text(raw.sector, MAX.short),
    size: text(raw.size, MAX.short),
    locations,
    website: domain(raw.website),
    facts,
    sources,
  }
}

/** The pages the web search used, from OpenRouter's url citations: https only, each once. */
export function sourcesFrom(annotations: unknown): Source[] {
  if (!Array.isArray(annotations)) return []
  const seen = new Set<string>()
  const sources: Source[] = []
  for (const note of annotations) {
    const citation = note?.url_citation
    const url = typeof citation?.url === 'string' ? citation.url : undefined
    if (!url || !url.startsWith('https://') || seen.has(url)) continue
    seen.add(url)
    sources.push({ title: text(citation.title, MAX.short) ?? domain(url) ?? url, url })
    if (sources.length === MAX.sources) break
  }
  return sources
}

export type AboutSearch = (company: string, city?: string) => Promise<CompanyAbout | undefined>

export function webAboutSearch(apiKey: string, fetchImpl: Fetch = fetch): AboutSearch {
  return async (company, city) => {
    const response = await fetchImpl('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: SMALL,
        provider: PROVIDER,
        temperature: 0,
        max_tokens: 500,
        plugins: [{ id: 'web', engine: 'exa', max_results: 4 }],
        messages: [
          { role: 'system', content: PROMPT },
          { role: 'user', content: `Bedrijf: ${company}${city ? `, ${city}` : ''}` },
        ],
      }),
      signal: AbortSignal.timeout(20_000),
    })
    if (!response.ok) return undefined
    const message = (await response.json().catch(() => null))?.choices?.[0]?.message
    return aboutFromAnswer(message?.content, message?.annotations)
  }
}
