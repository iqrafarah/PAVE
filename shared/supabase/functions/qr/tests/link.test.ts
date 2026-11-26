import { assertEquals } from 'jsr:@std/assert@1'
import { allowedLink } from '../link.ts'

Deno.test('only links to a share or an employer become a QR code', () => {
  assertEquals(allowedLink('https://pave.example.nl/werkgever/kade-consultancy'), 'https://pave.example.nl/werkgever/kade-consultancy')
  assertEquals(allowedLink(`http://localhost:3000/gedeeld/${'a'.repeat(32)}`), `http://localhost:3000/gedeeld/${'a'.repeat(32)}`)
  assertEquals(allowedLink('https://evil.example/login'), null)
  assertEquals(allowedLink('https://pave.example.nl/werkgever/kade?x=1'), null)
  assertEquals(allowedLink('javascript:alert(1)'), null)
  assertEquals(allowedLink(null), null)
})
