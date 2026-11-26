// The fixed sentences PAVE writes itself (questions before an action, asking for the vault, Ja and Nee, what changed
// in a plan) in the language of the app. What the model writes is already in that language; these are not, because
// the code that makes them stays Dutch. The reply is translated just before it leaves, so the checks in brain.ts keep
// working on the Dutch words.
import type { AylaReply, Language } from './contract.ts'

type Other = Exclude<Language, 'nl'>

/** Dutch with {1}, {2} for the parts that vary, and the same sentence in English and Papiamentu. */
const SENTENCES: [nl: string, en: string, pap: string][] = [
  ['Ja', 'Yes', 'Si'],
  ['Nee', 'No', 'Nò'],
  ['Kies zelf', 'Choose myself', 'Skohe mi mes'],
  ['Sorry, dat lukte me even niet. Wil je het nog een keer vragen?', "Sorry, that didn't work just now. Could you ask again?", 'Despensá, esei no a bai awor. Bo por puntra di nobo?'],
  ['Dit heb ik gevonden. Er meer over vertellen lukte me nu niet; vraag gerust door over een van deze vacatures.', "This is what I found. I couldn't tell you more about it just now; feel free to ask about any of these vacancies.", 'Esaki mi a haña. Mi no por a konta mas awor; puntra tranki tokante un di e vakaturanan aki.'],
  ['Opleidingen zoeken doe ik op je iPhone. Vraag het daar, dan zie je ze met een link naar de school.', "I look up studies on your iPhone. Ask me there and you'll see them with a link to the school.", 'Mi ta buska estudio riba bo iPhone. Puntra mi aya, i bo ta mira nan ku un link pa e skol.'],
  ['Dat staat al zo.', "That's already set.", 'Esei ta asina kaba.'],
  ['Wat bedoel je precies? Zeg even wat ik moet doen, dan regel ik het.', 'What do you mean exactly? Tell me what to do and I will take care of it.', 'Kiko bo ke men eksaktamente? Bisa mi kiko mi mester hasi, i mi ta regla esaki.'],
  ['Dat onthoud ik niet, dus er is niets om te vergeten.', "I don't remember that, so there is nothing to forget.", 'Mi no ta kòrda esei, p\'esei no tin nada pa lubidá.'],
  ['Ik onthoud niets tussen gesprekken, dus er is niets om te vergeten.', "I don't remember anything between chats, so there is nothing to forget.", 'Mi no ta kòrda nada entre kombersashonnan, p\'esei no tin nada pa lubidá.'],
  ['Weet je het zeker?', 'Are you sure?', 'Bo ta sigur?'],
  ['Wil je iets toevoegen?', 'Would you like to add something?', 'Bo ke agregá algu?'],
  ['Mag ik in je kluis kijken om te laten zien welke vacatures bij je passen?', 'May I look in your vault to show which vacancies fit you?', 'Mi por wak den bo kaha fuerte pa mustra kua vakatura ta pas bo?'],
  ['Mag ik in je kluis kijken om te zien wat erin staat?', "May I look in your vault to see what's in it?", 'Mi por wak den bo kaha fuerte pa mira kiko tin aden?'],
  ['Mag ik in je kluis kijken om {1}?', 'May I look in your vault to {1}?', 'Mi por wak den bo kaha fuerte pa {1}?'],
  ['Zal ik dit gesprek verwijderen?', 'Shall I delete this chat?', 'Mi mester kita e kombersashon aki?'],
  ['Zal ik {1} uit je kluis verwijderen? Dat kan niet ongedaan worden gemaakt.', 'Shall I delete {1} from your vault? This cannot be undone.', 'Mi mester kita {1} for di bo kaha fuerte? Esaki no por wòrdu deshasí.'],
  ['Zal ik je uitloggen?', 'Shall I sign you out?', 'Mi mester saká bo for di bo kuenta?'],
  ['Zal ik alles vergeten wat ik over je onthoud? Dat kan niet ongedaan worden gemaakt.', 'Shall I forget everything I remember about you? This cannot be undone.', 'Mi mester lubidá tur loke mi ta kòrda di bo? Esaki no por wòrdu deshasí.'],
  ['Mag ik {1} voortaan bekijken en gebruiken?', 'May I view and use {1} from now on?', 'Mi por mira i usa {1} di awor padilanti?'],
  ['Zal ik de stap {1} uit je plan halen?', 'Shall I remove the step {1} from your plan?', 'Mi mester kita e paso {1} for di bo plan?'],
  ['Zal ik {1} laten weten dat je niet kunt?', "Shall I let {1} know you can't make it?", 'Mi mester laga {1} sa ku bo no por?'],
  ['Zal ik {1} laten weten dat je komt?', "Shall I let {1} know you're coming?", 'Mi mester laga {1} sa ku bo ta bini?'],
  ['Zal ik {1} als bron toevoegen aan {2}? Dan mag ik het bekijken en gebruiken in dat project.', 'Shall I add {1} as a source to {2}? Then I may view and use it in that project.', 'Mi mester agregá {1} komo fuente na {2}? Anto mi por mira i usa esaki den e proyekto ei.'],
  ['Zal ik {1} als bron toevoegen? Dan mag ik het bekijken en gebruiken in dat project.', 'Shall I add {1} as a source? Then I may view and use it in that project.', 'Mi mester agregá {1} komo fuente? Anto mi por mira i usa esaki den e proyekto ei.'],
  ['Stap {1} afgerond', 'Step {1} done', 'Paso {1} kla'],
  ['Stap {1} overgeslagen', 'Step {1} skipped', 'Paso {1} saltá'],
  ['Stap {1} nu bezig', 'Working on step {1}', 'Paso {1} awor ta kurando'],
  ['Plan {1} gemaakt', 'Plan {1} made', 'Plan {1} traha'],
  ['{1} in je kluis zetten bij {2}', 'Put {1} in your vault under {2}', 'Pone {1} den bo kaha fuerte bou di {2}'],
]

/** The vault's sections, as the app names them. */
const CATEGORIES: Record<string, [en: string, pap: string]> = {
  "Diploma's": ['Diplomas', 'Diplomanan'],
  Certificaten: ['Certificates', 'Sertifikadonan'],
  Badges: ['Badges', 'Insignianan'],
  Projecten: ['Projects', 'Proyektonan'],
  Werkervaring: ['Work experience', 'Eksperensia di trabou'],
  Stages: ['Internships', 'Stashinan'],
  Vaardigheden: ['Skills', 'Abilidatnan'],
  Feedback: ['Feedback', 'Feedback'],
  Reflecties: ['Reflections', 'Refleksionnan'],
  Overige: ['Other', 'Otro'],
}

const escape = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

const PATTERNS = SENTENCES.map(([nl, en, pap]) => ({
  match: new RegExp(`^${escape(nl).replace(/\\\{(\d)\\\}/g, '(.+?)')}$`, 's'),
  en,
  pap,
}))

/** One piece that varies: a list of names keeps its quotes but gets the right word for "en", a section its own name. */
function part(value: string, language: Other): string {
  const category = CATEGORIES[value]
  if (category) return language === 'en' ? category[0] : category[1]
  return value.replace(/" en "/g, language === 'en' ? '" and "' : '" i "')
}

/** A fixed Dutch sentence in the other language; anything else as it was. */
export function localized(text: string, language: Language | undefined): string {
  if (!language || language === 'nl' || !text) return text
  for (const pattern of PATTERNS) {
    const found = text.match(pattern.match)
    if (!found) continue
    return pattern[language].replace(/\{(\d)\}/g, (_, n) => part(found[Number(n)] ?? '', language))
  }
  return text
}

/** The reply with its fixed sentences in the language of the app. */
export function localizedReply(reply: AylaReply, language: Language | undefined): AylaReply {
  if (!language || language === 'nl') return reply
  const out: AylaReply = { ...reply, text: localized(reply.text, language) }
  if (reply.question) {
    out.question = {
      ...reply.question,
      text: localized(reply.question.text, language),
      choices: reply.question.choices.map((choice) => ({ ...choice, label: localized(choice.label, language) })),
    }
  }
  if (reply.proposedAction) out.proposedAction = { ...reply.proposedAction, summary: localized(reply.proposedAction.summary, language) }
  return out
}
