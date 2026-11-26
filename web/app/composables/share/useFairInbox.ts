// The employer's side of the fair demo (Edge Function fair-inbox): with the employer's secret key, see who applied and
// invite someone for a talk. In the demo a classmate plays the recruiter; the employers themselves are not connected.

export interface InboxApplication {
  id: string;
  vacancyTitle: string;
  name?: string;
  headline?: string;
  why?: string;
  pitch?: string;
  availability: { days: string[]; maxHours?: number };
  status: 'new' | 'invited' | 'declined';
  invitedFor?: string;
  answer?: 'accepted' | 'declined';
  appliedAt: string;
}

export interface EmployerInbox {
  employer?: { name: string; stand?: string };
  applications: InboxApplication[];
}

export function useFairInbox(slug: string, secret: string) {
  const { url, key } = useRuntimeConfig().public.supabase;
  const inbox = ref<EmployerInbox | null>(null);
  const problem = ref<'wrong_key' | 'failed' | null>(null);

  async function call(body: Record<string, string>) {
    try {
      const response = await fetch(`${url}/functions/v1/fair-inbox`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: key },
        body: JSON.stringify({ slug, key: secret, ...body }),
      });
      if (response.status === 403) {
        problem.value = 'wrong_key';
        return false;
      }
      if (!response.ok) {
        problem.value = 'failed';
        return false;
      }
      inbox.value = (await response.json()) as EmployerInbox;
      problem.value = null;
      return true;
    } catch {
      problem.value = 'failed';
      return false;
    }
  }

  const load = () => call({ action: 'list' });
  const invite = (applicationID: string, moment: Date, message: string) =>
    call({ action: 'invite', applicationID, moment: moment.toISOString(), message });

  return { inbox, problem, load, invite };
}
