// Meldingen › Van de beurs (iOS NotificationFairSection): an employer at the fair invites you for a talk. You answer
// here with "Ik kom" or "Kan niet"; the database only lets you change that answer (fair_applications).

export interface FairInvitation {
  id: string;
  employerSlug: string;
  employerName: string;
  vacancyTitle: string;
  /** ISO date of the talk. */
  invitedFor: string | null;
  message: string | null;
  answer: 'accepted' | 'declined' | null;
}

interface InvitationRow {
  id: string;
  employer_slug: string;
  vacancy_title: string;
  invited_for: string | null;
  invitation_message: string | null;
  answer: string | null;
}

/** "ogd" or "sioux-technologies" as a name when the employer is not in the list any more. */
function nameFromSlug(slug: string) {
  return slug
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

/** Waiting for your answer first, then the talks you said yes to that are still to come. */
export function shownInvitations(invitations: FairInvitation[], now = Date.now()) {
  const waiting = invitations.filter((invitation) => invitation.answer === null);
  const coming = invitations.filter(
    (invitation) => invitation.answer === 'accepted' && invitation.invitedFor !== null && new Date(invitation.invitedFor).getTime() > now,
  );
  return [...waiting, ...coming];
}

export function useFairInvitations() {
  const supabase = useUntypedSupabase();
  const invitations = useState<FairInvitation[]>('pave-fair-invitations', () => []);
  const shown = computed(() => shownInvitations(invitations.value));

  async function load() {
    const { data, error } = await supabase
      .from('fair_applications')
      .select('id,employer_slug,vacancy_title,invited_for,invitation_message,answer')
      .eq('status', 'invited')
      .order('invited_for', { ascending: true });
    // Without the fair tables (an older database) there is simply nothing from the fair.
    if (error || !data) return;
    const rows = data as InvitationRow[];
    const slugs = [...new Set(rows.map((row) => row.employer_slug))];
    const names = new Map<string, string>();
    if (slugs.length) {
      const { data: employers } = await supabase.from('fair_employers').select('slug,name').in('slug', slugs);
      for (const employer of (employers ?? []) as { slug: string; name: string }[]) names.set(employer.slug, employer.name);
    }
    invitations.value = rows.map((row) => ({
      id: row.id,
      employerSlug: row.employer_slug,
      employerName: names.get(row.employer_slug) ?? nameFromSlug(row.employer_slug),
      vacancyTitle: row.vacancy_title,
      invitedFor: row.invited_for,
      message: row.invitation_message?.trim() || null,
      answer: row.answer === 'accepted' || row.answer === 'declined' ? row.answer : null,
    }));
  }

  /** Shows the answer at once; when the database refuses it, it goes back. */
  async function answer(id: string, accepted: boolean) {
    const before = invitations.value;
    invitations.value = before.map((invitation) => (invitation.id === id ? { ...invitation, answer: accepted ? 'accepted' : 'declined' } : invitation));
    const { data, error } = await supabase
      .from('fair_applications')
      .update({ answer: accepted ? 'accepted' : 'declined' })
      .eq('id', id)
      .select('id');
    if (error || !data?.length) {
      invitations.value = before;
      return { error: FAIR_ANSWER_FAILED };
    }
    return { error: null };
  }

  return { invitations, shown, load, answer };
}
