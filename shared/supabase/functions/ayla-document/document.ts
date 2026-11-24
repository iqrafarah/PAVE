// Ayla writes along with a CV and a motivation letter: the profile and the line under the name, what was done at each
// job and project in the words of a CV, the letter, or one block again in another way. She only gets the vacancy, the user's name and the evidence she may see, and writes nothing that is
// not in there.

export type DocumentKind = 'profile' | 'entries' | 'letter' | 'rewrite'
export type Rewrite = 'shorter' | 'stronger' | 'english' | 'formal' | 'personal'

export interface DocumentItem { id: string; title: string; category: string; organisation?: string; period?: string; description?: string; skills: string[] }
export interface DocumentVacancy { title: string; company: string; city?: string; summary?: string; matches: string[]; skillGap: string[] }
export interface DocumentRequest {
  kind: DocumentKind
  vacancy: DocumentVacancy
  name: string
  items: DocumentItem[]
  text?: string
  rewrite?: Rewrite
  tone: 'formal' | 'personal'
}

export interface LetterParagraphOut { text: string; sourceItemIDs: string[] }
export interface EntryOut { sourceItemID: string; text: string }
export interface DocumentAnswer {
  profile?: string; headline?: string; entries?: EntryOut[]
  salutation?: string; paragraphs?: LetterParagraphOut[]; closing?: string; text?: string
}

const MAX_ITEMS = 20
const MAX_TEXT = 3000
const REWRITES: Rewrite[] = ['shorter', 'stronger', 'english', 'formal', 'personal']

export const DOCUMENT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['profile', 'headline', 'entries', 'salutation', 'paragraphs', 'closing', 'text'],
  properties: {
    profile: { type: ['string', 'null'] },
    headline: { type: ['string', 'null'] },
    entries: {
      type: ['array', 'null'],
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['source', 'text'],
        properties: { source: { type: 'integer' }, text: { type: 'string' } },
      },
    },
    salutation: { type: ['string', 'null'] },
    paragraphs: {
      type: ['array', 'null'],
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['text', 'sources'],
        properties: { text: { type: 'string' }, sources: { type: 'array', items: { type: 'integer' } } },
      },
    },
    closing: { type: ['string', 'null'] },
    text: { type: ['string', 'null'] },
  },
} as const

const text = (value: unknown, max: number) => (typeof value === 'string' ? value.trim().slice(0, max) : '')
const list = (value: unknown, max = 12) => (Array.isArray(value) ? value.map((entry) => text(entry, 120)).filter(Boolean).slice(0, max) : [])

/** The checked request, or what is wrong with it. */
export function parseDocumentRequest(body: unknown): DocumentRequest | string {
  if (!body || typeof body !== 'object') return 'body'
  const b = body as Record<string, unknown>
  if (b.kind !== 'profile' && b.kind !== 'entries' && b.kind !== 'letter' && b.kind !== 'rewrite') return 'kind'
  const v = b.vacancy as Record<string, unknown> | undefined
  const vacancy: DocumentVacancy = {
    title: text(v?.title, 200), company: text(v?.company, 200), city: text(v?.city, 200) || undefined,
    summary: text(v?.summary, 600) || undefined, matches: list(v?.matches), skillGap: list(v?.skillGap),
  }
  if (!vacancy.title || !vacancy.company) return 'vacancy'
  if (!Array.isArray(b.items) || b.items.length > MAX_ITEMS) return 'items'
  const items: DocumentItem[] = []
  for (const raw of b.items as Record<string, unknown>[]) {
    const item: DocumentItem = {
      id: text(raw?.id, 80), title: text(raw?.title, 200), category: text(raw?.category, 40),
      organisation: text(raw?.organisation, 200) || undefined, period: text(raw?.period, 60) || undefined,
      description: text(raw?.description, 600) || undefined, skills: list(raw?.skills, 10),
    }
    if (!item.id || !item.title) return 'items'
    items.push(item)
  }
  const request: DocumentRequest = { kind: b.kind, vacancy, name: text(b.name, 120), items, tone: b.tone === 'formal' ? 'formal' : 'personal' }
  if (b.kind === 'rewrite') {
    const original = text(b.text, MAX_TEXT)
    if (!original || !REWRITES.includes(b.rewrite as Rewrite)) return 'rewrite'
    request.text = original
    request.rewrite = b.rewrite as Rewrite
  }
  return request
}

const RULES = `
Je schrijft mee aan een sollicitatie in PAVE, namens de gebruiker, in de ik-vorm tenzij de opdracht om een andere vorm vraagt.
- Gebruik alleen wat in de vacature en de bewijsstukken hieronder staat. Verzin geen diploma's, werkervaring, cijfers, jaartallen, namen of vaardigheden, en doe niet alsof iets geverifieerd is.
- Zeg niets over het bedrijf wat niet in de vacature staat: geen producten, klanten, waarden of werkwijze. Waarom deze vacature aanspreekt, haal je uit wat de vacature vraagt en wat de gebruiker heeft gedaan.
- De gebruiker solliciteert nog: schrijf nooit alsof hij of zij de functie al heeft ("als junior ontwikkelaar heb ik").
- Maak niets mooier dan het bewijs zegt: "testte met gebruikers" blijft testen met gebruikers, geen "feedback verwerkt".
- Schrijf in helder, natuurlijk Nederlands, tenzij gevraagd wordt om Engels.
- Geen gedachtestreepjes, geen opsommingstekens, geen emoji, geen holle woorden als "gepassioneerd" of "dynamisch".
- Vul alleen de velden in die bij de opdracht horen; de andere zijn null.
`.trim()

const REWRITE_ASK: Record<Rewrite, string> = {
  shorter: 'Maak de tekst ongeveer de helft korter. Houd de belangrijkste feiten.',
  stronger: 'Maak de tekst sterker voor deze vacature: leg de nadruk op wat de vacature vraagt en wat de gebruiker daarvan kan laten zien.',
  english: 'Vertaal de tekst naar natuurlijk Engels, met dezelfde inhoud.',
  formal: 'Maak de toon formeler en zakelijker, met dezelfde inhoud.',
  personal: 'Maak de toon persoonlijker en warmer, met dezelfde inhoud.',
}

function context(request: DocumentRequest): string {
  const v = request.vacancy
  const vacancy = [
    `Vacature: ${v.title} bij ${v.company}${v.city ? ` in ${v.city}` : ''}.`,
    v.summary ? `Uit de vacaturetekst: ${v.summary}` : '',
    v.matches.length ? `Wat past: ${v.matches.join(', ')}.` : '',
    v.skillGap.length ? `Wat de gebruiker nog mist: ${v.skillGap.join(', ')}. Noem dit niet als iets wat de gebruiker kan.` : '',
  ].filter(Boolean).join('\n')
  const items = request.items.length
    ? request.items.map((item, index) => {
      const parts = [item.title, item.organisation, item.period].filter(Boolean).join(', ')
      const skills = item.skills.length ? ` Vaardigheden: ${item.skills.join(', ')}.` : ''
      const about = item.description ? ` ${item.description}` : ''
      return `${index + 1}. (${item.category}) ${parts}.${about}${skills}`
    }).join('\n')
    : 'Geen bewijsstukken die Ayla mag gebruiken. Schrijf dan algemeen en kort, zonder ervaring te noemen.'
  return `${vacancy}\n\nNaam: ${request.name || 'onbekend'}\n\nBewijsstukken:\n${items}`
}

/** The messages for the model: the rules, then what to write, with everything she may use. */
export function documentMessages(request: DocumentRequest): { role: 'system' | 'user'; content: string }[] {
  const tone = request.tone === 'formal' ? 'formeel en zakelijk' : 'vriendelijk en persoonlijk, maar professioneel'
  let ask: string
  switch (request.kind) {
    case 'profile':
      ask = 'Schrijf in "profile" een profieltekst voor bovenaan het cv: 2 of 3 zinnen, samen hooguit 55 woorden, gericht op deze vacature. Zet in "headline" de regel onder de naam: wat de gebruiker nu is of doet volgens de bewijsstukken, hooguit 5 woorden, zoals "Student HBO-ICT" of "Stagiair webdevelopment". Nooit de functie uit de vacature, en geen zin.'
      break
    case 'entries':
      ask = 'Schrijf voor het cv bij elk bewijsstuk hierboven dat een beschrijving heeft wat de gebruiker daar deed, in de stijl van een cv: 1 of 2 korte zinnen, samen hooguit 30 woorden, zonder "ik" of "je" als onderwerp, beginnend met een werkwoord ("Bouwde een iOS-app in SwiftUI.", "Plan de avonddiensten en werk nieuwe collega\'s in."). Loopt het nog, schrijf dan in de tegenwoordige tijd, anders in de verleden tijd. Gebruik alleen feiten uit de beschrijving van dat ene bewijsstuk en laat weg wat er niet toe doet; heeft een bewijsstuk geen beschrijving, sla het dan over. Zet in "entries" per bewijsstuk het nummer in "source" en de tekst in "text".'
      break
    case 'letter':
      ask = `Schrijf een motivatiebrief. "salutation": een aanhef zoals "Beste team van ${request.vacancy.company},". "paragraphs": 3 of 4 alinea's: waarom deze vacature en dit bedrijf, wat de gebruiker meebrengt met concrete voorbeelden uit de bewijsstukken (zet in "sources" de nummers van de bewijsstukken die een alinea noemt), en een afsluiting die uitnodigt tot een gesprek. Samen hooguit 230 woorden. "closing": "Met vriendelijke groet,". Toon: ${tone}.`
      break
    case 'rewrite':
      ask = `${REWRITE_ASK[request.rewrite!]} Voeg niets toe wat niet al in de tekst staat, ook niet uit de bewijsstukken. Zet het resultaat in "text".\n\nDe tekst:\n${request.text}`
      break
  }
  return [
    { role: 'system', content: RULES },
    { role: 'user', content: `${context(request)}\n\n${ask}` },
  ]
}

/** No dashes as punctuation, no surrounding quotes, single spaces. */
export function cleanWriting(value: unknown, max = 1500): string | undefined {
  if (typeof value !== 'string') return undefined
  const cleaned = value
    .replace(/\s*[—–]\s*/g, ', ')
    .replace(/^["'“”]+|["'“”]+$/g, '')
    .replace(/[ \t]+/g, ' ')
    .trim()
  return cleaned ? cleaned.slice(0, max) : undefined
}

/** What the model wrote, checked: sources only point at evidence that was sent. */
export function documentAnswer(raw: unknown, request: DocumentRequest): DocumentAnswer {
  const r = (raw ?? {}) as Record<string, unknown>
  const answer: DocumentAnswer = {}
  if (request.kind === 'profile') {
    answer.profile = cleanWriting(r.profile, 600)
    answer.headline = cleanWriting(r.headline, 60)?.replace(/[.!]+$/, '')
  }
  if (request.kind === 'entries') {
    const seen = new Set<number>()
    answer.entries = (Array.isArray(r.entries) ? r.entries : [])
      .filter((e: Record<string, unknown>) => {
        const n = e?.source
        if (typeof n !== 'number' || !Number.isInteger(n) || n < 1 || n > request.items.length || seen.has(n)) return false
        // Nothing to go on means nothing to write: an entry without a description keeps what the vault says.
        if (!request.items[n - 1].description) return false
        seen.add(n)
        return true
      })
      .map((e: Record<string, unknown>) => ({ sourceItemID: request.items[(e.source as number) - 1].id, text: cleanWriting(e.text, 400) ?? '' }))
      .filter((e: EntryOut) => e.text)
  }
  if (request.kind === 'rewrite') answer.text = cleanWriting(r.text, MAX_TEXT)
  if (request.kind === 'letter') {
    answer.salutation = cleanWriting(r.salutation, 120)
    answer.closing = cleanWriting(r.closing, 120)
    answer.paragraphs = (Array.isArray(r.paragraphs) ? r.paragraphs : [])
      .map((p: Record<string, unknown>) => ({
        text: cleanWriting(p?.text) ?? '',
        sourceItemIDs: (Array.isArray(p?.sources) ? p.sources : [])
          .filter((n: unknown): n is number => typeof n === 'number' && Number.isInteger(n) && n >= 1 && n <= request.items.length)
          .map((n: number) => request.items[n - 1].id),
      }))
      .filter((p: LetterParagraphOut) => p.text)
      .slice(0, 5)
  }
  return answer
}
