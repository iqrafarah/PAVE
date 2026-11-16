import type { SignedInDevice } from '~/utils/settings/devices';

type DevicesProblem = keyof typeof DEVICES_ERRORS;
// notSetUp: the database functions are not there yet (migration 20261112150000).
type DevicesStatus = 'idle' | 'loading' | 'ready' | 'notSetUp' | 'failed';

interface DevicesState {
  status: DevicesStatus;
  devices: SignedInDevice[];
  loadError: string | null;
  // The device that is being signed out, or every other one ('allOthers').
  signingOut: string | null;
  problem: string | null;
}

interface SessionRow {
  id: string;
  signed_in_at: string;
  last_active_at: string;
  user_agent: string | null;
  is_current: boolean;
}

const ALL_OTHERS = 'allOthers';

function problemOf(error: { code?: string; message?: string } | null): DevicesProblem {
  if (!error) return 'unavailable';
  // PostgREST does not know the function (PGRST202), or the table behind it is missing.
  if (error.code === 'PGRST202' || error.code === '42883') return 'notSetUp';
  if (error.code === '42501') return 'notAllowed';
  if (error.code === 'PGRST301' || error.code === '401') return 'notSignedIn';
  if (error.message?.includes('Failed to fetch')) return 'noConnection';
  return 'unavailable';
}

/**
 * The devices the account is signed in on, for Instellingen (iOS SignedInDevicesModel). The sessions are read through
 * `my_sessions` and one is ended through `end_my_session`; signing out everywhere else goes through Supabase Auth
 * itself, so it also works before the migration ran. A device that is signed out leaves the list straight away.
 */
export function useSignedInDevices() {
  const supabase = useUntypedSupabase();
  const state = useState<DevicesState>('pave-devices', () => ({
    status: 'idle',
    devices: [],
    loadError: null,
    signingOut: null,
    problem: null,
  }));

  const current = computed(() => state.value.devices.find((device) => device.isCurrent) ?? null);
  const others = computed(() => state.value.devices.filter((device) => !device.isCurrent));

  async function load() {
    if (!state.value.devices.length) state.value.status = 'loading';
    const { data, error } = await supabase.rpc('my_sessions');
    if (error) {
      const problem = problemOf(error);
      if (problem === 'notSetUp') state.value.status = 'notSetUp';
      else if (!state.value.devices.length) {
        state.value.status = 'failed';
        state.value.loadError = DEVICES_ERRORS[problem];
      } else state.value.problem = DEVICES_ERRORS[problem];
      return;
    }
    state.value.devices = ((data ?? []) as SessionRow[]).map((row) => ({
      id: row.id,
      ...describeUserAgent(row.user_agent ?? ''),
      signedInAt: row.signed_in_at,
      lastActiveAt: row.last_active_at,
      isCurrent: row.is_current,
    }));
    state.value.status = 'ready';
    state.value.loadError = null;
  }

  async function signOut(device: SignedInDevice) {
    if (state.value.signingOut) return;
    state.value.signingOut = device.id;
    state.value.problem = null;
    const { error } = await supabase.rpc('end_my_session', { target: device.id });
    if (error) state.value.problem = DEVICES_ERRORS[problemOf(error)];
    else state.value.devices = state.value.devices.filter((entry) => entry.id !== device.id);
    state.value.signingOut = null;
  }

  async function signOutOthers() {
    if (state.value.signingOut) return;
    state.value.signingOut = ALL_OTHERS;
    state.value.problem = null;
    const { error } = await supabase.auth.signOut({ scope: 'others' });
    if (error) state.value.problem = DEVICES_ERRORS.unavailable;
    else state.value.devices = state.value.devices.filter((entry) => entry.isCurrent);
    state.value.signingOut = null;
  }

  return { state, current, others, load, signOut, signOutOthers, ALL_OTHERS };
}
