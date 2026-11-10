// Calls the Mistral models through OpenRouter, like the demo: if a model is
// slow, the next one starts alongside it and the first good answer wins.
// When the caller wants to see the answer while it is written (`onContent`), the
// models stream: the first one that starts writing wins and the others stop.

export const MODELS = ['mistralai/mistral-medium-3.1', 'mistralai/mistral-small-3.2-24b-instruct', 'mistralai/mistral-large-2512']
export const HEDGE_MS = 3500
const TIMEOUT_MS = 25000

export interface ChatMessage { role: 'system' | 'user' | 'assistant'; content: string }

export interface CompleteOptions {
  /** Called with everything the model wrote so far, while it writes. */
  onContent?: (contentSoFar: string) => void
  /** Stops the models, for instance when the user taps stop. */
  signal?: AbortSignal
}

export type Complete = (messages: ChatMessage[], options?: CompleteOptions) => Promise<{ model: string; content: string }>

export function openRouterCompletion(apiKey: string, responseSchema: object, fetchImpl: typeof fetch = fetch, models = MODELS, hedgeMs = HEDGE_MS): Complete {
  return (messages, options = {}) => {
    const controllers: AbortController[] = []
    const streams = !!options.onContent
    let next = 0
    let failed = 0
    let done = false
    let leader: string | undefined

    return new Promise((resolve, reject) => {
      const stopAll = () => controllers.forEach((c) => c.abort())
      if (options.signal?.aborted) return reject(new DOMException('stopped', 'AbortError'))
      options.signal?.addEventListener('abort', () => {
        if (done) return
        done = true
        stopAll()
        reject(new DOMException('stopped', 'AbortError'))
      })

      const launch = () => {
        if (done || leader || next >= models.length) return
        const model = models[next++]
        const controller = new AbortController()
        controllers.push(controller)
        const hedge = setTimeout(launch, hedgeMs)
        const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS)

        fetchImpl('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model,
            temperature: 0.4,
            max_tokens: 600,
            messages,
            ...(streams ? { stream: true } : {}),
            response_format: { type: 'json_schema', json_schema: { name: 'ayla_reply', strict: true, schema: responseSchema } },
          }),
          signal: controller.signal,
        })
          .then(async (response) => {
            if (!response.ok) throw new Error(`${model} answered ${response.status}`)
            if (!streams) {
              const json = await response.json()
              return json?.choices?.[0]?.message?.content
            }
            return await readStream(response, (content) => {
              if (done) return
              if (!leader) {
                // This model writes first: it answers, the others stop.
                leader = model
                clearTimeout(hedge)
                controllers.filter((c) => c !== controller).forEach((c) => c.abort())
              }
              if (leader === model) options.onContent?.(content)
            })
          })
          .then((content) => {
            clearTimeout(hedge)
            clearTimeout(timeout)
            if (typeof content !== 'string' || !content.trim()) throw new Error(`empty answer from ${model}`)
            if (done) return
            done = true
            stopAll()
            resolve({ model, content })
          })
          .catch((error) => {
            clearTimeout(hedge)
            clearTimeout(timeout)
            if (done) return
            // Once a model has started writing, its failure is the answer's failure.
            if (leader === model || ++failed === models.length) {
              done = true
              stopAll()
              reject(error)
            } else if (!leader) {
              launch()
            }
          })
      }
      launch()
    })
  }
}

/** Reads OpenRouter's server-sent events and returns everything the model wrote. */
async function readStream(response: Response, onContent: (content: string) => void): Promise<string> {
  const reader = response.body?.getReader()
  if (!reader) return ''
  const decoder = new TextDecoder()
  let buffer = ''
  let content = ''
  while (true) {
    const { value, done } = await reader.read()
    if (done) break
    buffer += decoder.decode(value, { stream: true })
    let newline: number
    while ((newline = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, newline).trim()
      buffer = buffer.slice(newline + 1)
      if (!line.startsWith('data:')) continue
      const data = line.slice(5).trim()
      if (data === '[DONE]') return content
      try {
        const delta = JSON.parse(data)?.choices?.[0]?.delta?.content
        if (typeof delta === 'string' && delta) {
          content += delta
          onContent(content)
        }
      } catch {
        // A comment or keep-alive line.
      }
    }
  }
  return content
}
