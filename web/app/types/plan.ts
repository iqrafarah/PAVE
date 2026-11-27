// Plans (iOS PAVECore PavePlan; tables plans and plan_steps, migration 20261125130000): a personal workspace where
// someone works towards one goal, step by step, with Ayla.

export type PlanStepStatus = 'upcoming' | 'active' | 'done' | 'skipped';

/** An open set: a flow can bring kinds of its own; an unknown kind looks like a general step. */
export type PlanStepKind =
  | 'general'
  | 'conversation'
  | 'research'
  | 'evidence'
  | 'verification'
  | 'document'
  | 'action'
  | 'reflection'
  | 'milestone'
  | 'profile'
  | 'contact'
  | (string & {});

export interface PlanStep {
  id: string;
  title: string;
  /** A short line about what the step is. */
  summary: string;
  kind: PlanStepKind;
  status: PlanStepStatus;
  /** The chat where this step was worked on, if any. */
  conversationId: string | null;
  completedAt: string | null;
  metadata: Record<string, string>;
}

/** A chat with Ayla that belongs to a plan, optionally for one step. */
export interface PlanConversation {
  id: string;
  title: string;
  stepId: string | null;
  addedAt: string;
}

export interface Plan {
  id: string;
  name: string;
  /** What the plan works towards, in the user's own words; may be empty. */
  goal: string;
  /** The template it started from, for its icon. */
  templateId: string | null;
  steps: PlanStep[];
  conversations: PlanConversation[];
  createdAt: string;
  updatedAt: string;
  /** When the plan was finished; null while it is still going. */
  completedAt: string | null;
  /** Free room for the flow that made it: the vacancy it is about, its project. */
  metadata: Record<string, string>;
}

export interface PlanTemplateStep {
  title: string;
  summary: string;
  kind: PlanStepKind;
  metadata?: Record<string, string>;
}

export interface PlanTemplate {
  id: string;
  name: string;
  /** One line about what the template is for. */
  summary: string;
  goal: string;
  steps: PlanTemplateStep[];
  metadata?: Record<string, string>;
}
