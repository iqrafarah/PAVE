// Calls the Mistral models through OpenRouter, like the demo: if a model is
// slow, the next one starts alongside it and the first good answer wins.

export const MODELS = ['mistralai/mistral-medium-3.1', 'mistralai/mistral-small-3.2-24b-instruct', 'mistralai/mistral-large-2512']
export const HEDGE_MS = 3500
const TIMEOUT_MS = 25000

export interface ChatMessage { role: 'system' | 'user' | 'assistant'; content: string }

export type Complete = (messages: ChatMessage[]) => Promise<{ model: string; content: string }>

export function openRouterCompletion(apiKey: string, responseSchema: object, fetchImpl: typeof fetch = fetch, models = MODELS, hedgeMs = HEDGE_MS): Complete {
  return (messages) => {
    const controllers: AbortController[] = []
    let next = 0
    let failed = 0
    let done = false

    return new Promise((resolve, reject) => {
      const launch = () => {
        if (done || next >= models.length) return
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
            response_format: { type: 'json_schema', json_schema: { name: 'ayla_reply', strict: true, schema: responseSchema } },
          }),
          signal: controller.signal,
        })
          .then(async (response) => {
            if (!response.ok) throw new Error(`${model} answered ${response.status}`)
            const json = await response.json()
            const content = json?.choices?.[0]?.message?.content
            if (typeof content !== 'string' || !content.trim()) throw new Error(`empty answer from ${model}`)
            return content
          })
          .then((content) => {
            clearTimeout(hedge)
            clearTimeout(timeout)
            if (done) return
            done = true
            controllers.forEach((c) => c.abort())
            resolve({ model, content })
          })
          .catch((error) => {
            clearTimeout(hedge)
            clearTimeout(timeout)
            if (done) return
            if (++failed === models.length) reject(error)
            else launch()
          })
      }
      launch()
    })
  }
}
