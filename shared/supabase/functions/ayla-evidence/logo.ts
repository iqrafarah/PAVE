// The logo of an organisation, from its own website, when the documents have none ("Laat Ayla invullen"). Only the
// domain goes out, never the user's document or name. The app shows where the logo came from, and the user can replace
// it. SVG is left out: the iPhone cannot draw it as a logo image.
//
// Several places are tried at once: the logo the site names in its page data (schema.org), its Apple icon, its other
// icons and Google's icon service. Each image is measured, and the sharpest one that is about square wins, because the
// logo sits in a round avatar.

export type Fetch = (input: string, init?: RequestInit) => Promise<Response>

export interface FoundLogo { data: string; mimeType: string; source: string }

interface Candidate { url: string; bonus: number }
interface Measured { data: Uint8Array; mimeType: string; width: number; height: number; bonus: number }

const PAGE_LIMIT = 1_500_000
const IMAGE_LIMIT = 600_000
const MAX_CANDIDATES = 8
const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/x-icon', 'image/vnd.microsoft.icon']
/** Some sites refuse anything that does not look like a browser. */
const USER_AGENT = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'

/** The best logo of the site at `domain`, or undefined; never throws. */
export async function findLogo(domain: string, fetchImpl: Fetch = fetch, timeoutMs = 4000): Promise<FoundLogo | undefined> {
  if (!isPublicDomain(domain)) return undefined
  const candidates: Candidate[] = [
    { url: `https://www.google.com/s2/favicons?domain=${domain}&sz=256`, bonus: 0 },
    { url: `https://${domain}/apple-touch-icon.png`, bonus: 10 },
  ]
  const page = await firstPage(domain, fetchImpl, timeoutMs)
  if (page) candidates.unshift(...logosIn(page.html, page.url), ...iconsIn(page.html, page.url))
  const unique = [...new Map(candidates.map((candidate) => [candidate.url, candidate])).values()].slice(0, MAX_CANDIDATES)
  const measured = await Promise.all(unique.map((candidate) => measuredImage(candidate, fetchImpl, timeoutMs)))
  const best = pickBest(measured.filter((image): image is Measured => !!image))
  return best ? { data: toBase64(best.data), mimeType: best.mimeType, source: domain } : undefined
}

/** About square and as sharp as possible; a wide banner or a tiny icon only when nothing better is there. */
export function pickBest(images: Measured[]): Measured | undefined {
  const score = (image: Measured) => {
    const side = Math.min(image.width, image.height)
    const ratio = Math.max(image.width, image.height) / Math.max(1, side)
    const shape = ratio <= 1.35 ? 1 : ratio <= 2.2 ? 0.3 : 0.1
    return Math.min(side, 512) * shape + image.bonus
  }
  return images.filter((image) => image.width >= 16 && image.height >= 16).sort((a, b) => score(b) - score(a))[0]
}

/** A host name on the internet, not an address or a name inside a network. */
export function isPublicDomain(domain: string): boolean {
  if (!/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}$/.test(domain)) return false
  return !/(^|\.)(localhost|local|internal|lan|home|corp|test|example|invalid)$/.test(domain)
}

/** The logo the page names in its schema.org data, such as `"logo": {"url": "…/coolblue_logo.png"}`. */
export function logosIn(html: string, pageURL: string): Candidate[] {
  const logos: Candidate[] = []
  for (const match of html.matchAll(/"logo"\s*:\s*(?:"([^"]+)"|\{[^{}]*?"(?:url|contentUrl)"\s*:\s*"([^"]+)")/g)) {
    const url = absolute((match[1] ?? match[2]).replace(/\\\//g, '/'), pageURL)
    if (url && !/\.svg(\?|#|$)/i.test(url)) logos.push({ url, bonus: 40 })
  }
  return logos.slice(0, 2)
}

/** The icons a page links to: the Apple icon a little above the others. */
export function iconsIn(html: string, pageURL: string): Candidate[] {
  const icons: Candidate[] = []
  for (const tag of html.match(/<link\b[^>]*>/gi) ?? []) {
    const rel = attribute(tag, 'rel')?.toLowerCase() ?? ''
    const href = attribute(tag, 'href')
    if (!href || !/\b(icon|apple-touch-icon(-precomposed)?)\b/.test(rel)) continue
    const type = attribute(tag, 'type')?.toLowerCase() ?? ''
    if (type.includes('svg') || /\.svg(\?|#|$)/i.test(href)) continue
    const url = absolute(href, pageURL)
    if (url) icons.push({ url, bonus: rel.includes('apple-touch-icon') ? 20 : 5 })
  }
  return icons
}

/** Width and height from the first bytes of a PNG, JPEG, GIF, WebP or ICO file. */
export function imageSize(bytes: Uint8Array): { width: number; height: number } | undefined {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const at = (offset: number, length: number) => String.fromCharCode(...bytes.subarray(offset, offset + length))
  if (bytes.length >= 24 && at(1, 3) === 'PNG') return { width: view.getUint32(16), height: view.getUint32(20) }
  if (bytes.length >= 10 && at(0, 3) === 'GIF') return { width: view.getUint16(6, true), height: view.getUint16(8, true) }
  if (bytes.length >= 30 && at(0, 4) === 'RIFF' && at(8, 4) === 'WEBP') {
    const chunk = at(12, 4)
    if (chunk === 'VP8 ') return { width: view.getUint16(26, true) & 0x3fff, height: view.getUint16(28, true) & 0x3fff }
    if (chunk === 'VP8L') {
      const bits = view.getUint32(21, true)
      return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 }
    }
    if (chunk === 'VP8X') {
      return { width: 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16)), height: 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16)) }
    }
  }
  if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2
    while (offset + 9 < bytes.length) {
      if (bytes[offset] !== 0xff) return undefined
      const marker = bytes[offset + 1]
      const length = view.getUint16(offset + 2)
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        return { width: view.getUint16(offset + 7), height: view.getUint16(offset + 5) }
      }
      offset += 2 + length
    }
    return undefined
  }
  if (bytes.length >= 22 && view.getUint16(0, true) === 0 && view.getUint16(2, true) === 1) {
    let largest = { width: 0, height: 0 }
    const count = Math.min(view.getUint16(4, true), 16)
    for (let entry = 0; entry < count && 6 + entry * 16 + 2 <= bytes.length; entry++) {
      const width = bytes[6 + entry * 16] || 256
      const height = bytes[7 + entry * 16] || 256
      if (width > largest.width) largest = { width, height }
    }
    return largest.width ? largest : undefined
  }
  return undefined
}

async function firstPage(domain: string, fetchImpl: Fetch, timeoutMs: number): Promise<{ html: string; url: string } | undefined> {
  for (const url of [`https://${domain}/`, `https://www.${domain}/`]) {
    const found = await get(url, fetchImpl, timeoutMs)
    if (!found?.response.ok || !(found.response.headers.get('content-type') ?? '').includes('html')) continue
    const bytes = await limited(found.response, PAGE_LIMIT)
    if (bytes) return { html: new TextDecoder().decode(bytes), url: found.url }
  }
  return undefined
}

async function measuredImage(candidate: Candidate, fetchImpl: Fetch, timeoutMs: number): Promise<Measured | undefined> {
  const response = (await get(candidate.url, fetchImpl, timeoutMs))?.response
  const mimeType = (response?.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase()
  if (!response?.ok || !IMAGE_TYPES.includes(mimeType)) return undefined
  const data = await limited(response, IMAGE_LIMIT)
  const size = data && data.length >= 100 ? imageSize(data) : undefined
  return data && size ? { data, mimeType, ...size, bonus: candidate.bonus } : undefined
}

function absolute(href: string, pageURL: string): string | undefined {
  try {
    const url = new URL(href, pageURL)
    return url.protocol === 'https:' ? url.href : undefined
  } catch {
    return undefined
  }
}

function attribute(tag: string, name: string): string | undefined {
  const match = tag.match(new RegExp(`\\b${name}\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i'))
  const value = match?.[2] ?? match?.[3] ?? match?.[4]
  return value?.replace(/&amp;/g, '&').trim() || undefined
}

/** Every address is checked before it is asked for, also each one a redirect leads to: https and on the internet. */
async function get(url: string, fetchImpl: Fetch, timeoutMs: number): Promise<{ response: Response; url: string } | undefined> {
  let current = url
  const signal = AbortSignal.timeout(timeoutMs)
  for (let hop = 0; hop < 4; hop++) {
    let address: URL
    try {
      address = new URL(current)
    } catch {
      return undefined
    }
    if (address.protocol !== 'https:' || !isPublicDomain(address.hostname)) return undefined
    let response: Response
    try {
      response = await fetchImpl(address.href, { signal, redirect: 'manual', headers: { 'User-Agent': USER_AGENT, Accept: '*/*' } })
    } catch {
      return undefined
    }
    if (response.status < 300 || response.status >= 400) return { response, url: address.href }
    const location = response.headers.get('location')
    if (!location) return undefined
    current = new URL(location, address).href
  }
  return undefined
}

async function limited(response: Response, limit: number): Promise<Uint8Array | undefined> {
  const length = Number(response.headers.get('content-length') ?? 0)
  if (length > limit) return undefined
  try {
    const buffer = new Uint8Array(await response.arrayBuffer())
    return buffer.length > limit ? undefined : buffer
  } catch {
    return undefined
  }
}

export function toBase64(bytes: Uint8Array): string {
  let binary = ''
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  return btoa(binary)
}
