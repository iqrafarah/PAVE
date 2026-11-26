// A fake OpenRouter for the iOS integration tests: the local `ayla` edge function talks to this instead of the real
// model (OPENROUTER_BASE_URL in shared/supabase/functions/.env). It always gives the same answer, costs nothing and
// needs no key. Started and stopped by ios/scripts/integration-tests.sh.
//
//   POST /api/v1/chat/completions   answers like OpenRouter: streamed (server-sent events) or as one JSON
//   GET  /requests                  what it was asked so far, for the tests to check
import { createServer } from 'node:http'

const PORT = Number(process.env.FAKE_OPENROUTER_PORT ?? 55399)

// The same text the tests expect (AylaIntegrationTests.swift).
export const ANSWER_TEXT = 'Hallo! Dit is een testantwoord van de nep-OpenRouter.'

// What the model writes for Ayla's reply schema: the minimal shape brain.ts accepts (see ayla/tests/brain.test.ts).
const reply = JSON.stringify({ text: ANSWER_TEXT, question: null, navigation: null, vacancySearch: null, title: 'Testgesprek' })

const requests = []

function lastUserText(messages) {
  const last = [...(messages ?? [])].reverse().find((m) => m.role === 'user')
  if (!last) return null
  return typeof last.content === 'string' ? last.content : JSON.stringify(last.content)
}

const server = createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/requests') {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    return res.end(JSON.stringify(requests))
  }
  if (req.method !== 'POST' || !req.url?.endsWith('/chat/completions')) {
    res.writeHead(404)
    return res.end()
  }

  let body = ''
  req.on('data', (chunk) => (body += chunk))
  req.on('end', () => {
    let parsed = {}
    try {
      parsed = JSON.parse(body)
    } catch {
      res.writeHead(400)
      return res.end()
    }
    requests.push({ model: parsed.model, stream: !!parsed.stream, userText: lastUserText(parsed.messages) })

    if (!parsed.stream) {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      return res.end(JSON.stringify({ choices: [{ message: { role: 'assistant', content: reply } }] }))
    }

    // Streamed in small pieces, like a real model, so the app also gets the text while it is being written.
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' })
    res.write(': OPENROUTER PROCESSING\n\n')
    for (let i = 0; i < reply.length; i += 12) {
      res.write(`data: ${JSON.stringify({ choices: [{ delta: { content: reply.slice(i, i + 12) } }] })}\n\n`)
    }
    res.write('data: [DONE]\n\n')
    res.end()
  })
})

server.listen(PORT, '0.0.0.0', () => console.log(`fake OpenRouter on http://127.0.0.1:${PORT}`))
