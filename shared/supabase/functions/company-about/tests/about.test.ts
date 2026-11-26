import { assertEquals } from 'jsr:@std/assert@1'
import { aboutFromAnswer, domain, sourcesFrom, webAboutSearch } from '../about.ts'

const citations = [
  { type: 'url_citation', url_citation: { url: 'https://kade.nl/over-ons', title: 'Over Kade' } },
  { type: 'url_citation', url_citation: { url: 'https://kade.nl/over-ons', title: 'Dubbel' } },
  { type: 'url_citation', url_citation: { url: 'http://onveilig.nl', title: 'Geen https' } },
  { type: 'url_citation', url_citation: { url: 'https://werkenbij.kade.nl', title: '' } },
]

Deno.test('the answer is checked, cut to size and keeps its sources', () => {
  const answer = JSON.stringify({
    about: 'Kade adviseert middelgrote bedrijven over cloud en beveiliging.',
    sector: 'IT-advies',
    size: 'null',
    locations: ['Eindhoven', '', 'Utrecht', 'Breda', 'Zwolle'],
    website: 'https://www.kade.nl/',
    facts: [{ label: 'Traineeship', text: 'Starters volgen een jaar lang een traineeship.' }, { label: '', text: 'zonder label' }],
  })
  const about = aboutFromAnswer(`Hier is het: ${answer}`, citations)
  assertEquals(about?.about, 'Kade adviseert middelgrote bedrijven over cloud en beveiliging.')
  assertEquals(about?.size, undefined)
  assertEquals(about?.locations, ['Eindhoven', 'Utrecht', 'Breda'])
  assertEquals(about?.website, 'kade.nl')
  assertEquals(about?.facts.length, 1)
  assertEquals(about?.sources.map((s) => s.url), ['https://kade.nl/over-ons', 'https://werkenbij.kade.nl'])
  assertEquals(about?.sources[1].title, 'werkenbij.kade.nl')
})

Deno.test('nothing found, not JSON, or no source means nothing is shown', () => {
  assertEquals(aboutFromAnswer('{"about":null}', citations), undefined)
  assertEquals(aboutFromAnswer('geen idee', citations), undefined)
  assertEquals(aboutFromAnswer('{"about":"Een bedrijf."}', []), undefined)
  assertEquals(aboutFromAnswer(undefined, citations), undefined)
})

Deno.test('sources and domains', () => {
  assertEquals(sourcesFrom('x'), [])
  assertEquals(domain('https://www.Kade.nl/x'), 'kade.nl')
  assertEquals(domain('geen'), undefined)
})

Deno.test('the search sends only the name and place, with the web plugin, and reads the citations', async () => {
  let sent: Record<string, unknown> = {}
  const fake = (_url: string, init?: RequestInit) => {
    sent = JSON.parse(String(init?.body))
    return Promise.resolve(new Response(JSON.stringify({
      choices: [{ message: { content: '{"about":"Kade adviseert over cloud.","locations":["Eindhoven"],"facts":[]}', annotations: citations } }],
    })))
  }
  const about = await webAboutSearch('key', fake as typeof fetch)('Kade Consultancy', 'Eindhoven')
  const messages = sent.messages as { content: string }[]
  assertEquals(messages[1].content, 'Bedrijf: Kade Consultancy, Eindhoven')
  assertEquals((sent.plugins as { id: string }[])[0].id, 'web')
  assertEquals(about?.about, 'Kade adviseert over cloud.')
})
