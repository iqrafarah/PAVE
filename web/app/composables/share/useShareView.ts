// What someone shares with you through a link (Edge Function share-view, see shared/supabase/functions/share-view).
// Opening it is written down for the owner, with the name you give, if any.

export interface SharedItem {
  id: string;
  category: string;
  title: string;
  description?: string;
  organisation?: string;
  startDate?: string;
  endDate?: string;
  issuedOn?: string;
  isCurrent: boolean;
  verified: boolean;
  skills: string[];
}

export interface SharedLetter {
  salutation?: string;
  paragraphs?: { text: string }[];
  closing?: string;
  signature?: string;
}

export interface SharedView {
  state: 'active' | 'paused' | 'revoked' | 'expired' | 'unknown';
  title?: string;
  purpose?: string;
  recipient?: { name: string; organisation?: string };
  expiresAt?: string;
  allowsDownload?: boolean;
  profile?: { name: string; headline?: string; email?: string; phone?: string; city?: string; summary?: string };
  items?: SharedItem[];
  letter?: SharedLetter;
  documents?: { kind: 'cv' | 'letter'; url: string }[];
}

export function useShareView(code: string) {
  const { url, key } = useRuntimeConfig().public.supabase;
  const view = ref<SharedView | null>(null);
  const failed = ref(false);
  const loading = ref(false);

  async function open(viewer?: { name?: string; organisation?: string }, action: 'view' | 'download' = 'view') {
    loading.value = true;
    failed.value = false;
    try {
      const response = await fetch(`${url}/functions/v1/share-view`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: key },
        body: JSON.stringify({ code, action, viewer }),
      });
      const body = (await response.json().catch(() => null)) as SharedView | null;
      if (!body || (!response.ok && !body.state)) {
        failed.value = true;
        return null;
      }
      view.value = body;
      return body;
    } catch {
      failed.value = true;
      return null;
    } finally {
      loading.value = false;
    }
  }

  return { view, failed, loading, open };
}

/** "februari 2026", in Dutch, from "2026-02-01". */
export function monthYear(date?: string): string | undefined {
  if (!date) return undefined;
  return new Date(date).toLocaleDateString('nl-NL', { month: 'long', year: 'numeric' });
}

export function period(item: SharedItem): string | undefined {
  if (item.issuedOn && !item.startDate) return monthYear(item.issuedOn);
  const start = monthYear(item.startDate);
  if (!start) return monthYear(item.endDate);
  if (item.isCurrent) return `${start} – nu`;
  const end = monthYear(item.endDate);
  return end && end !== start ? `${start} – ${end}` : start;
}

export const CATEGORY_TITLES: Record<string, string> = {
  diplomas: 'Diploma’s',
  certificates: 'Certificaten',
  badges: 'Badges',
  projects: 'Projecten',
  internships: 'Stages',
  workExperience: 'Werkervaring',
  skills: 'Vaardigheden',
  feedback: 'Feedback',
  reflections: 'Reflecties',
};
