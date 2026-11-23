// Calls the Mistral models through OpenRouter, like the demo: if a model is
// slow, the next one starts alongside it and the first good answer wins.
// When the caller wants to see the answer while it is written (`onContent`), the
// models stream: the first one that starts writing wins and the others stop.
//
// Only models that Mistral hosts itself, and every request says so (`PROVIDER`): OpenRouter serves some Mistral models
// through other companies (mistral-small-3.2 only through DeepInfra, Parasail and Venice), and what people tell Ayla
// should go to Mistral alone. Models are retired without notice (mistral-medium-3.1 was, in 2026): a model that
// answers with an error is logged by name, and `node evals/run.ts` shows which ones still answer.

const SMALL = 'mistralai/mistral-small-2603'
const STEADY = 'mistralai/mistral-large-2512'
const STRONG = 'mistralai/mistral-medium-3-5'

export const MODELS = [STEADY, STRONG, SMALL]
export const HEDGE_MS = 3500
/** OpenRouter may only send a request to Mistral's own servers. */
export const PROVIDER = { only: ['mistral'] }

/** How much thinking a turn asks for: a greeting, an ordinary question, or real work. */
export type Effort = 'light' | 'normal' | 'hard'

/**
 * The models for a turn, the best fit first; the others still join when it is slow or fails. Hard work starts with the
 * strongest model and gives it longer to begin, so the quicker ones do not take the turn from it. The small model
 * follows the prompt least well: outside a greeting it is the last resort (Mistral refuses requests when it is busy,
 * and the turn then goes to the next model at once).
 */
export function modelsFor(effort: Effort): { models: string[]; hedgeMs: number } {
  switch (effort) {
    case 'light': return { models: [SMALL, STEADY, STRONG], hedgeMs: 2500 }
    case 'hard': return { models: [STRONG, STEADY, SMALL], hedgeMs: 6000 }
    default: return { models: [STEADY, STRONG, SMALL], hedgeMs: HEDGE_MS }
  }
}
const TIMEOUT_MS = 25000

export type ContentPart = { type: 'text'; text: string } | { type: 'image_url'; image_url: { url: string } }

export interface ChatMessage { role: 'system' | 'user' | 'assistant'; content: string | ContentPart[] }

export interface CompleteOptions {
  /** Called with everything the model wrote so far, while it writes. */
  onContent?: (contentSoFar: string) => void
  /** Stops the models, for instance when the user taps stop. */
  signal?: AbortSignal
  /** Picks the models for this turn; without it, the ones this function was made with. */
  effort?: Effort
  /** More room than usual for this answer, such as a match for every vacancy. */
  maxTokens?: number
  /** Another shape than usual for this answer, such as the round that only compares vacancies. */
  schema?: object
}

export type Complete = (messages: ChatMessage[], options?: CompleteOptions) => Promise<{ model: string; content: string }>

/** A chat reply is short; a whole evidence item with its skills and sources needs more room, and more time with photos. */
export interface CompletionLimits { maxTokens?: number; timeoutMs?: number }

export function openRouterCompletion(
  apiKey: string,
  responseSchema: object,
  fetchImpl: typeof fetch = fetch,
  models = MODELS,
  hedgeMs = HEDGE_MS,
  limits: CompletionLimits = {},
): Complete {
  const maxTokens = limits.maxTokens ?? 600
  const timeoutMs = limits.timeoutMs ?? TIMEOUT_MS
  return (messages, options = {}) => {
    const controllers: AbortController[] = []
    const streams = !!options.onContent
    // Only the standard list is reordered: a caller that chose its own models keeps them.
    const chosen = options.effort && models === MODELS ? modelsFor(options.effort) : { models, hedgeMs }
    const turnModels = chosen.models
    const turnHedgeMs = chosen.hedgeMs
    const turnTokens = options.maxTokens ?? maxTokens
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
        if (done || leader || next >= turnModels.length) return
        const model = turnModels[next++]
        const controller = new AbortController()
        controllers.push(controller)
        const hedge = setTimeout(launch, turnHedgeMs)
        const timeout = setTimeout(() => controller.abort(), timeoutMs)

        fetchImpl('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model,
            temperature: 0.4,
            max_tokens: turnTokens,
            messages,
            provider: PROVIDER,
            ...(streams ? { stream: true } : {}),
            response_format: { type: 'json_schema', json_schema: { name: 'ayla_reply', strict: true, schema: options.schema ?? responseSchema } },
          }),
          signal: controller.signal,
        })
          .then(async (response) => {
            if (!response.ok) {
              // The name of the model and the status only, never what was asked: a retired model shows up here.
              console.warn(`ayla: ${model} answered ${response.status}`)
              throw new Error(`${model} answered ${response.status}`)
            }
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
            if (leader === model || ++failed === turnModels.length) {
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

const MAX_TRAILING_SPACE = 120

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
          // A model that only writes spaces and tabs any more never finishes its JSON: what it wrote is the answer.
          if (content.length - content.trimEnd().length > MAX_TRAILING_SPACE) {
            await reader.cancel().catch(() => {})
            return content.trimEnd()
          }
          onContent(content)
        }
      } catch {
        // A comment or keep-alive line.
      }
    }
  }
  return content
}
