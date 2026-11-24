import { assertEquals } from 'jsr:@std/assert@1'
import { bareDomain, companyLogo, lookupProblem, siteFromAnswer } from '../lookup.ts'

const png = (side: number) => {
  const bytes = new Uint8Array(200)
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52])
  new DataView(bytes.buffer).setUint32(16, side)
  new DataView(bytes.buffer).setUint32(20, side)
  return bytes
}

/** A web where only `site` exists, with an Apple icon of 180 pixels. */
const webWith = (site: string) => (input: string) => {
  const url = String(input)
  if (url === `https://${site}/apple-touch-icon.png`) return Promise.resolve(new Response(png(180), { headers: { 'content-type': 'image/png' } }))
  return Promise.resolve(new Response('nope', { status: 404 }))
}

Deno.test('a name and place are needed, and never a job site', () => {
  assertEquals(lookupProblem('Appwerk', 'Eindhoven'), null)
  assertEquals(lookupProblem('Appwerk', undefined), null)
  assertEquals(lookupProblem('', 'Eindhoven'), 'invalid_request')
  assertEquals(lookupProblem('Via werkzoeken.nl', null), 'invalid_request')
  assertEquals(lookupProblem('x'.repeat(201), null), 'invalid_request')
  assertEquals(lookupProblem('Appwerk', 3), 'invalid_request')
})

Deno.test('a domain is written bare', () => {
  assertEquals(bareDomain('https://www.OGD.nl/vacatures?x=1'), 'ogd.nl')
  assertEquals(bareDomain('geen domein'), undefined)
})

Deno.test('the site the model named is read from its answer', () => {
  assertEquals(siteFromAnswer('{"site":"https://www.fontys.nl"}'), 'fontys.nl')
  assertEquals(siteFromAnswer('Hier: {"site":null}'), undefined)
  assertEquals(siteFromAnswer('geen json'), undefined)
})

Deno.test('the company name itself is tried first', async () => {
  let searched = false
  const logo = await companyLogo('Appwerk', 'Eindhoven', () => { searched = true; return Promise.resolve(undefined) }, webWith('appwerk.nl'))
  assertEquals(logo, { url: 'https://appwerk.nl/apple-touch-icon.png', site: 'appwerk.nl' })
  assertEquals(searched, false)
})

Deno.test('a site from the search must fit the company', async () => {
  const fitting = await companyLogo('Studio Noord BV', 'Tilburg', () => Promise.resolve('studio-noord.com'), webWith('studio-noord.com'))
  assertEquals(fitting?.site, 'studio-noord.com')
  const other = await companyLogo('Studio Noord BV', 'Tilburg', () => Promise.resolve('pixelwerk.nl'), webWith('pixelwerk.nl'))
  assertEquals(other, undefined)
})
