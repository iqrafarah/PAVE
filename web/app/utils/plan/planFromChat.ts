import type { PlanTemplateStep } from '~/types/plan';

// A plan from a chat with Ayla: whether the user asks for one, and the steps Ayla wrote in her answer. The words are
// the ones the Ayla function listens for (MAKES_PLAN, STEP_PLAN and OWN_PLAN in brain.ts); keep them the same.

const MAKES_PLAN =
  /\b(maak|maken|start|begin|zet)\w*\b[^.?!]{0,40}\b(stappen)?plan\b|\b(stappen)?plan\b[^.?!]{0,40}\b(maken|starten|beginnen|opzetten)\b/i;
const STEP_PLAN = /\bstappenplan\b/i;
/** A plan the user already has: "mijn plan", "dit plan". */
const OWN_PLAN = /\b(mijn|dit|dat|het|je|jouw) (stappen)?plan\b/i;
/** "1. Je cv bijwerken", "2) Vacatures zoeken". */
const NUMBERED_LINE = /^\s*\d{1,2}[.)]\s+(.+)$/;
/** "Maand 1-2: …", "Week 3 – …": a moment in front of the step itself. */
const MOMENT = /^(maand|maanden|week|weken|dag|dagen|jaar|stap)\b[\s\d–-]*$/i;
/** How the request starts, up to what the plan is for: "Kun je een stappenplan maken om …". */
const REQUEST_START =
  /^.*?\b(stappen)?plan\b(\s+(maken|opzetten|starten))?(\s+(om|voor|zodat|waarmee|waarin|over|naar|richting))?\s*/i;
const MIN_STEPS = 2;
const MAX_STEPS = 8;

export function asksForNewPlan(text: string) {
  return !OWN_PLAN.test(text) && (MAKES_PLAN.test(text) || STEP_PLAN.test(text));
}

/** "Je cv bijwerken: zet je laatste werk erin." becomes the title and a summary. */
function toStep(line: string): PlanTemplateStep | null {
  const plain = line.replace(/\*+/g, '').trim();
  const [head = '', ...rest] = plain.split(/\s*[:–—]\s+|\s+-\s+/);
  const isMoment = MOMENT.test(head) && rest.length > 0;
  const titleText = isMoment ? rest.shift()! : head;
  const title = cleanPlanName(titleText.replace(/[.;,]$/, ''));
  if (!title) return null;
  return { title, summary: cleanPlanGoal(rest.join(': ')), kind: 'general' };
}

/** The numbered steps of Ayla's answer, in order; none when she wrote fewer than two. */
export function stepsFromAnswer(text: string): PlanTemplateStep[] {
  const steps = text
    .split('\n')
    .map((line) => line.match(NUMBERED_LINE)?.[1])
    .filter((line): line is string => Boolean(line))
    .map(toStep)
    .filter((step): step is PlanTemplateStep => step !== null)
    .slice(0, MAX_STEPS);
  return steps.length >= MIN_STEPS ? steps : [];
}

/** A first name for the plan from what was asked: "Maak een stappenplan om een stage te vinden" → "Een stage te vinden". */
export function planNameFromQuestion(question: string) {
  const goal = question
    .replace(REQUEST_START, '')
    .replace(/[?.!]+$/, '')
    .replace(/\bte (\p{L}+)$/u, '$1')
    .trim();
  const name = cleanPlanName(goal.charAt(0).toLocaleUpperCase('nl') + goal.slice(1));
  return name ?? '';
}
