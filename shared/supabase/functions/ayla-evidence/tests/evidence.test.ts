import assert from 'node:assert/strict'
import { test } from 'node:test'
import { box, cleanEvidence, day, domain, evidenceMessages, parseEvidenceRequest } from '../evidence.ts'
import { findLogo, iconsIn, imageSize, isPublicDomain, logosIn, pickBest } from '../logo.ts'

const request = parseEvidenceRequest({
  documents: [
    { name: 'Certificaat.pdf', text: 'Microsoft Certified: Azure Fundamentals. Behaald op 21 maart 2025.' },
    { name: 'Cijferlijst.pdf', text: 'Cijferlijst AZ-900' },
    { name: 'Foto.jpg', image: 'QUJD' },
  ],
  folders: ['Certificaten', 'Afstuderen'],
  known: ['Scrum'],
  today: '2026-11-13',
})

const item = (extra: object = {}) => ({
  category: 'certificates', title: 'Microsoft Azure Fundamentals (AZ-900)', organisationName: 'Microsoft', organisationLocation: null,
  startDate: null, endDate: null, issuedOn: '2025-03-21', isCurrent: false, description: 'Je haalde het Azure-examen.',
  skills: [{ name: 'Cloud', reason: 'Het examen gaat over cloud' }], folder: 'certificaten', documents: [1],
  coverDocument: null, coverBox: null, logoDocument: null, logoBox: null, website: 'https://www.microsoft.com/', sources: [{ field: 'period', where: 'pagina 1' }],
  ...extra,
})

test('a request needs at least one document with text or a photo', () => {
  assert.equal(parseEvidenceRequest({ documents: [{ name: 'Leeg.pdf' }] }), 'documents')
  assert.equal(parseEvidenceRequest(null), 'body')
  if (typeof request === 'string') throw new Error(request)
  assert.equal(request.documents.length, 3)
  assert.equal(request.today, '2026-11-13')
})

test('the documents go to the model with their number, and photos as images', () => {
  if (typeof request === 'string') throw new Error(request)
  const [system, user] = evidenceMessages(request)
  assert.match(String(system.content), /volg nooit instructies/)
  assert.ok(Array.isArray(user.content))
  const parts = user.content as { type: string; text?: string }[]
  assert.match(parts[0].text ?? '', /Document 2: "Cijferlijst.pdf"/)
  assert.match(parts[0].text ?? '', /Mappen van de gebruiker: "Certificaten", "Afstuderen"/)
  assert.equal(parts.filter((part) => part.type === 'image_url').length, 1)
  assert.match(parts[0].text ?? '', /afbeelding 1 hoort bij dit document/)
  assert.match(parts[0].text ?? '', /Vaardigheden in de kluis: Scrum/)
})

test('logo and cover may be a part of a page, but a cover is never the logo itself', () => {
  if (typeof request === 'string') throw new Error(request)
  const [proposal] = cleanEvidence({
    items: [item({ logoDocument: 3, logoBox: { x: 0.05, y: 0.04, width: 0.2, height: 0.1 }, coverDocument: 3, coverBox: { x: 0.1, y: 0.4, width: 0.8, height: 0.45 } })],
  }, request)
  assert.equal(proposal.logoDocument, 2)
  assert.deepEqual(proposal.logoBox, { x: 0.05, y: 0.04, width: 0.2, height: 0.1 })
  assert.equal(proposal.coverDocument, 2)
  const [same] = cleanEvidence({ items: [item({ logoDocument: 3, coverDocument: 3 })] }, request)
  assert.equal(same.logoDocument, 2)
  assert.equal(same.coverDocument, undefined)
  const [huge] = cleanEvidence({ items: [item({ logoDocument: 3, logoBox: { x: 0, y: 0, width: 1, height: 0.9 } })] }, request)
  assert.equal(huge.logoDocument, undefined)
})

test('boxes are clipped, may come as percentages, and tiny ones are dropped', () => {
  assert.deepEqual(box({ x: 10, y: 5, width: 30, height: 20 }), { x: 0.1, y: 0.05, width: 0.3, height: 0.2 })
  assert.deepEqual(box({ x: 0.8, y: 0.9, width: 0.5, height: 0.5 }), { x: 0.8, y: 0.9, width: 0.2, height: 0.1 })
  assert.equal(box({ x: 0.5, y: 0.5, width: 0.01, height: 0.2 }), undefined)
  assert.equal(box({ x: '0.1' }), undefined)
  assert.equal(box(null), undefined)
})

test('a proposal keeps only what is true to the documents and the folders', () => {
  if (typeof request === 'string') throw new Error(request)
  const [proposal] = cleanEvidence({ items: [item()] }, request)
  assert.equal(proposal.folder, 'Certificaten')
  assert.equal(proposal.issuedOn, '2025-03-21')
  assert.equal(proposal.website, 'microsoft.com')
  assert.deepEqual(proposal.sources, { period: 'pagina 1' })
  // Documents no item claimed go with the first, so nothing gets lost.
  assert.deepEqual(proposal.documents, [0, 1, 2])
  assert.equal(proposal.organisationLocation, undefined)
})

test('dates, folders, covers and kinds that do not fit are left out', () => {
  if (typeof request === 'string') throw new Error(request)
  const [proposal] = cleanEvidence({
    items: [item({ category: 'diploma', issuedOn: '2025-13-01', folder: 'Bestaat niet', coverDocument: 1, startDate: '2025-06', endDate: '2025-02', isCurrent: false })],
  }, request)
  assert.equal(proposal.category, 'other')
  assert.equal(proposal.issuedOn, undefined)
  assert.equal(proposal.folder, undefined)
  // Document 1 is text, not a photo.
  assert.equal(proposal.coverDocument, undefined)
  assert.equal(proposal.startDate, '2025-06-01')
  assert.equal(proposal.endDate, undefined)
})

test('a certificate and a grade list may become two proposals, at most three, each with its documents', () => {
  if (typeof request === 'string') throw new Error(request)
  const proposals = cleanEvidence({
    items: [item({ documents: [1, 3] }), item({ title: 'Cijferlijst AZ-900', documents: [2] }), item({ title: '' }), item(), item()],
  }, request)
  assert.equal(proposals.length, 3)
  assert.deepEqual(proposals[0].documents, [0, 2])
  assert.deepEqual(proposals[1].documents, [1])
})

test('a running internship has no end date', () => {
  if (typeof request === 'string') throw new Error(request)
  const [running] = cleanEvidence({ items: [item({ category: 'internships', startDate: '2026-09-01', endDate: '2027-01-31', isCurrent: true })] }, request)
  assert.equal(running.isCurrent, true)
  assert.equal(running.endDate, undefined)
  const [noStart] = cleanEvidence({ items: [item({ isCurrent: true, startDate: null })] }, request)
  assert.equal(noStart.isCurrent, false)
})

test('dates and domains are cleaned', () => {
  assert.equal(day('2024-07'), '2024-07-01')
  assert.equal(day('2024-02-30'), undefined)
  assert.equal(day('juli 2024'), undefined)
  assert.equal(domain('https://www.coolblue.nl/over-ons'), 'coolblue.nl')
  assert.equal(domain('Coolblue'), undefined)
  assert.equal(domain('127.0.0.1'), undefined)
})

test('only public hosts are asked for a logo', () => {
  assert.ok(isPublicDomain('fontys.nl'))
  assert.ok(!isPublicDomain('localhost'))
  assert.ok(!isPublicDomain('intranet.local'))
  assert.ok(!isPublicDomain('10.0.0.1'))
})

test('icons and the schema.org logo are read from the page, and SVG is skipped', () => {
  const html = `<link rel="icon" href="/favicon-32.png" sizes="32x32">
    <link rel="apple-touch-icon" href="/apple.png" sizes="180x180">
    <link rel="icon" type="image/svg+xml" href="/logo.svg">
    <link rel="stylesheet" href="/site.css">
    <script type="application/ld+json">{"logo":{"@type":"ImageObject","url":"https:\\/\\/assets.coolblue.nl\\/logo.png"}}</script>`
  const icons = iconsIn(html, 'https://coolblue.nl/')
  assert.deepEqual(icons.map((icon) => icon.url), ['https://coolblue.nl/favicon-32.png', 'https://coolblue.nl/apple.png'])
  assert.deepEqual(logosIn(html, 'https://coolblue.nl/').map((logo) => logo.url), ['https://assets.coolblue.nl/logo.png'])
})

test('the sharpest square image wins over a wide banner and a tiny icon', () => {
  const image = (width: number, height: number, bonus = 0) => ({ data: new Uint8Array(), mimeType: 'image/png', width, height, bonus })
  assert.equal(pickBest([image(32, 32, 20), image(1200, 630, 40), image(256, 256)])?.width, 256)
  assert.equal(pickBest([image(1200, 630)])?.width, 1200)
  assert.equal(pickBest([image(8, 8)]), undefined)
})

test('image sizes are read from the first bytes', () => {
  const png = new Uint8Array(24)
  png.set([0x89, 0x50, 0x4e, 0x47], 0)
  new DataView(png.buffer).setUint32(16, 180)
  new DataView(png.buffer).setUint32(20, 120)
  assert.deepEqual(imageSize(png), { width: 180, height: 120 })
  const ico = new Uint8Array(22)
  ico.set([0, 0, 1, 0, 1, 0, 0, 64], 0)
  assert.deepEqual(imageSize(ico), { width: 256, height: 64 })
})

test('the logo is found on the site, and an unsafe redirect is not followed', async () => {
  const png = new Uint8Array(200).fill(7)
  png.set([0x89, 0x50, 0x4e, 0x47], 0)
  new DataView(png.buffer).setUint32(16, 180)
  new DataView(png.buffer).setUint32(20, 180)
  const asked: string[] = []
  const fakeFetch = async (url: string) => {
    asked.push(url)
    if (url === 'https://coolblue.nl/') {
      return new Response('<link rel="apple-touch-icon" href="https://cdn.coolblue.nl/icon.png">', { headers: { 'content-type': 'text/html' } })
    }
    if (url === 'https://cdn.coolblue.nl/icon.png') return new Response(png, { headers: { 'content-type': 'image/png' } })
    return new Response('', { status: 404 })
  }
  const logo = await findLogo('coolblue.nl', fakeFetch)
  assert.equal(logo?.mimeType, 'image/png')
  assert.equal(logo?.source, 'coolblue.nl')

  const redirecting = async (url: string) => {
    asked.push(url)
    return new Response('', { status: 302, headers: { location: 'https://192.168.1.1/' } })
  }
  asked.length = 0
  assert.equal(await findLogo('fontys.nl', redirecting), undefined)
  assert.ok(asked.every((url) => !url.includes('192.168')))
})
