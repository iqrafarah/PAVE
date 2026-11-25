// The employers of the job fair demo, readable without an account (table fair_employers): fictional ones, and real
// ones with real vacancies read on the day they were added (created_at).

export interface FairVacancy {
  id: string;
  title: string;
  summary?: string;
  city?: string;
  url?: string;
}

export interface FairEmployer {
  slug: string;
  name: string;
  city?: string;
  about: string;
  stand?: string;
  vacancies: FairVacancy[];
  is_example: boolean;
  created_at?: string;
}

export async function loadFairEmployers(slug?: string): Promise<FairEmployer[]> {
  const supabase = useSupabaseClient();
  let query = supabase.from('fair_employers').select('slug,name,city,about,stand,vacancies,is_example,created_at').order('name');
  if (slug) query = query.eq('slug', slug);
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as unknown as FairEmployer[];
}

/** The QR code of a page of this site, as an SVG from the qr function (it only draws PAVE's own links). */
export function qrImage(path: string): string {
  const { url } = useRuntimeConfig().public.supabase;
  const link = `${window.location.origin}${path}`;
  return `${url}/functions/v1/qr?url=${encodeURIComponent(link)}`;
}
