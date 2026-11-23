// The demo wallet: what a learner's wallet could hold, made up. Every account gets its own five credentials, picked from
// the pool below by the account id, so the same account always sees the same wallet without anything being stored.
// Nothing here is real: the institutions are invented and nothing is checked. The apps say so ("demo").

export type Category = 'diplomas' | 'certificates' | 'badges' | 'internships' | 'workExperience'

export interface DemoCredential {
  /** Stable for this pool, so an import can name it. */
  id: string
  category: Category
  /** What kind of credential it is in a wallet, as the app shows it. */
  format: string
  title: string
  issuer: string
  place: string
  issuedOn?: string
  startDate?: string
  endDate?: string
  isCurrent?: boolean
  description: string
  skills: string[]
  /** The issuer's own site, to look up its logo. The made-up institutions have none, so they show the icon of their kind. */
  website?: string
}

const KEMPENLAND = 'Hogeschool Kempenland'

const DIPLOMAS: DemoCredential[] = [
  {
    id: 'diploma-havo', category: 'diplomas', format: 'Diploma', title: 'Havo-diploma', issuer: 'Kempenland College', place: 'Veldhoven',
    issuedOn: '2022-07-08', description: 'Je haalde je havo-diploma met het profiel Natuur en Techniek.', skills: ['Wiskunde', 'Engels'],
  },
  {
    id: 'diploma-mbo', category: 'diplomas', format: 'Diploma', title: 'Mbo-diploma Software Developer', issuer: 'ROC Kempenland', place: 'Eindhoven',
    issuedOn: '2023-07-05', description: 'Je haalde je mbo-diploma Software Developer op niveau 4.', skills: ['Programmeren', 'Databases', 'Testen'],
  },
  {
    id: 'diploma-propedeuse', category: 'diplomas', format: 'Diploma', title: 'Propedeuse HBO-ICT', issuer: KEMPENLAND, place: 'Eindhoven',
    issuedOn: '2024-07-12', description: 'Je rondde het eerste jaar van HBO-ICT af.', skills: ['Programmeren', 'Samenwerken'],
  },
]

const CERTIFICATES: DemoCredential[] = [
  {
    id: 'certificate-english', category: 'certificates', format: 'Certificaat', title: 'Engels B2', issuer: 'Taalinstituut Delta', place: 'Utrecht',
    issuedOn: '2024-03-21', description: 'Je toonde Engels aan op niveau B2 van het Europees Referentiekader.', skills: ['Engels'],
  },
  {
    id: 'certificate-first-aid', category: 'certificates', format: 'Certificaat', title: 'Eerste hulp', issuer: 'Stichting Eerste Hulp Zuid', place: 'Eindhoven',
    issuedOn: '2025-02-14', description: 'Je haalde je certificaat eerste hulp, met reanimatie en het gebruik van een AED.', skills: ['Eerste hulp'],
  },
  {
    id: 'certificate-scrum', category: 'certificates', format: 'Certificaat', title: 'Scrum Foundation', issuer: 'Agile Academie Brabant', place: "'s\u2011Hertogenbosch",
    issuedOn: '2025-05-30', description: 'Je kent de rollen, gebeurtenissen en afspraken van Scrum.', skills: ['Scrum', 'Samenwerken'],
  },
  {
    id: 'certificate-python', category: 'certificates', format: 'Certificaat', title: 'Python basis', issuer: 'Codeschool Delta', place: 'Utrecht',
    issuedOn: '2024-11-08', description: 'Je schreef programma\'s in Python met lijsten, functies en bestanden.', skills: ['Python', 'Programmeren'],
  },
]

const BADGES: DemoCredential[] = [
  {
    id: 'badge-presenting', category: 'badges', format: 'Open Badge', title: 'Presenteren voor een groep', issuer: KEMPENLAND, place: 'Eindhoven',
    issuedOn: '2024-12-13', description: 'Je presenteerde je project voor een groep en ging in op vragen.', skills: ['Presenteren'],
  },
  {
    id: 'badge-teamwork', category: 'badges', format: 'Open Badge', title: 'Samenwerken in een projectteam', issuer: KEMPENLAND, place: 'Eindhoven',
    issuedOn: '2025-01-24', description: 'Je werkte een semester in een projectteam en maakte afspraken over taken en planning.', skills: ['Samenwerken', 'Plannen'],
  },
  {
    id: 'badge-accessible', category: 'badges', format: 'Open Badge', title: 'Toegankelijk ontwerpen', issuer: KEMPENLAND, place: 'Eindhoven',
    issuedOn: '2025-06-20', description: 'Je ontwierp schermen die ook werken met een schermlezer en grote tekst.', skills: ['Toegankelijkheid', 'UX-ontwerp'],
  },
  {
    id: 'badge-research', category: 'badges', format: 'Open Badge', title: 'Onderzoeksvaardigheden', issuer: KEMPENLAND, place: 'Eindhoven',
    issuedOn: '2024-06-28', description: 'Je deed een klein onderzoek met interviews en schreef er een verslag over.', skills: ['Onderzoek', 'Rapporteren'],
  },
  {
    id: 'badge-privacy', category: 'badges', format: 'Open Badge', title: 'Privacy en de AVG', issuer: KEMPENLAND, place: 'Eindhoven',
    issuedOn: '2025-03-14', description: 'Je weet welke regels er gelden voor persoonsgegevens en past ze toe in een project.', skills: ['Privacy'],
  },
  {
    id: 'badge-feedback', category: 'badges', format: 'Open Badge', title: 'Feedback geven en ontvangen', issuer: KEMPENLAND, place: 'Eindhoven',
    issuedOn: '2025-09-26', description: 'Je gaf en kreeg feedback in je team en gebruikte die om je werk te verbeteren.', skills: ['Feedback geven', 'Reflecteren'],
  },
]

const EXPERIENCE: DemoCredential[] = [
  {
    id: 'internship-frontend', category: 'internships', format: 'Werkgeversverklaring', title: 'Stage front-end development', issuer: 'Studio Noord', place: 'Eindhoven',
    startDate: '2025-02-03', endDate: '2025-07-04', description: 'Je bouwde mee aan webapps in React en TypeScript, in een Scrum-team.', skills: ['React', 'TypeScript', 'Scrum'],
  },
  {
    id: 'internship-data', category: 'internships', format: 'Werkgeversverklaring', title: 'Stage data-analyse', issuer: 'Datalab Zuid', place: 'Tilburg',
    startDate: '2024-09-02', endDate: '2025-01-31', description: 'Je maakte overzichten van gegevens met SQL en Python en lichtte ze toe.', skills: ['SQL', 'Python', 'Rapporteren'],
  },
  {
    id: 'work-customer-service', category: 'workExperience', format: 'Werkgeversverklaring', title: 'Bijbaan klantenservice', issuer: 'Winkelhuis Zuid', place: 'Helmond',
    startDate: '2023-09-01', isCurrent: true, description: 'Je helpt klanten aan de telefoon en in de chat.', skills: ['Klantgericht werken', 'Communiceren'],
  },
]

/** All credentials any demo wallet can hold. */
export const POOL: DemoCredential[] = [...DIPLOMAS, ...CERTIFICATES, ...BADGES, ...EXPERIENCE]

/** A number from the account id that is the same every time (FNV-1a). */
function seedOf(userId: string): number {
  let hash = 0x811c9dc5
  for (const char of userId.toLowerCase()) {
    hash ^= char.charCodeAt(0)
    hash = Math.imul(hash, 0x01000193) >>> 0
  }
  return hash
}

/** A small random generator that gives the same numbers for the same seed (mulberry32). */
function generator(seed: number): () => number {
  let state = seed
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let t = state
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function pick<T>(list: T[], count: number, random: () => number): T[] {
  const rest = [...list]
  const picked: T[] = []
  while (picked.length < count && rest.length) picked.push(rest.splice(Math.floor(random() * rest.length), 1)[0])
  return picked
}

/** The five credentials in this account's wallet: a diploma, a certificate, two badges and a work experience. */
export function walletFor(userId: string): DemoCredential[] {
  const random = generator(seedOf(userId))
  return [...pick(DIPLOMAS, 1, random), ...pick(CERTIFICATES, 1, random), ...pick(BADGES, 2, random), ...pick(EXPERIENCE, 1, random)]
}

/** The same credential as an item already in the vault: taken from the wallet before, by title and institution. */
export function sameEvidence(credential: DemoCredential, item: { title?: string | null; organisation_name?: string | null }): boolean {
  const plain = (text: string | null | undefined) => (text ?? '').trim().toLocaleLowerCase('nl')
  return plain(item.title) === plain(credential.title) && plain(item.organisation_name) === plain(credential.issuer)
}

/** The row for `vault_items`: confirmed, because it came from the wallet, and marked as an import. */
export function itemRow(credential: DemoCredential, userId: string) {
  return {
    user_id: userId,
    category: credential.category,
    title: credential.title,
    description: credential.description,
    organisation_name: credential.issuer,
    organisation_location: credential.place,
    issued_on: credential.issuedOn ?? null,
    start_date: credential.startDate ?? null,
    end_date: credential.endDate ?? null,
    is_current: credential.isCurrent === true,
    verification_status: 'verified',
    source: 'import',
  }
}
