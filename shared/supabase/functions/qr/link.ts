// Only PAVE's own addresses become a QR code: a shared profile or an employer at a fair. Anything else is refused, so
// this is no free QR service for any link.

export function allowedLink(text: string | null): string | null {
  if (!text || text.length > 300) return null
  let url: URL
  try {
    url = new URL(text)
  } catch {
    return null
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return null
  if (url.search || url.hash || url.username || url.password) return null
  const ok = /^\/gedeeld\/[0-9a-f]{32}$/.test(url.pathname) || /^\/werkgever\/[a-z0-9-]{2,40}$/.test(url.pathname)
  return ok ? url.toString() : null
}
