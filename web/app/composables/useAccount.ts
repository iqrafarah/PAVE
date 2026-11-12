interface AccountState {
  fullName: string | null;
  avatarUrl: string | null;
  isLoaded: boolean;
}

/** The signed-in user's name and photo, loaded once and shared by the menu, the rail and the settings. */
export function useAccount() {
  const state = useState<AccountState>('pave-account', () => ({ fullName: null, avatarUrl: null, isLoaded: false }));
  const { getAccount } = useAyla();

  async function load() {
    if (state.value.isLoaded) return;
    const account = await getAccount();
    state.value = { fullName: account.fullName, avatarUrl: account.avatarUrl, isLoaded: true };
  }

  return { state, load };
}
