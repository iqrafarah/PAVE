// A QR code as SVG for a link of PAVE (see link.ts): the web page of a fair shows the employers' codes with it.
import QRCode from 'npm:qrcode@1.5.4'
import { allowedLink } from './link.ts'

Deno.serve(async (req) => {
  if (req.method !== 'GET') return new Response('method not allowed', { status: 405 })
  const link = allowedLink(new URL(req.url).searchParams.get('url'))
  if (!link) return new Response('not a PAVE link', { status: 400 })
  const svg = await QRCode.toString(link, { type: 'svg', errorCorrectionLevel: 'M', margin: 2, color: { dark: '#000000', light: '#ffffff' } })
  return new Response(svg, {
    headers: { 'Content-Type': 'image/svg+xml', 'Cache-Control': 'public, max-age=86400', 'Access-Control-Allow-Origin': '*' },
  })
})
