// Puts the chosen theme colour and text size on the page before it shows, on every page. The look is never worth
// breaking the site for: when anything here fails, PAVE simply starts in its standard look.
export default defineNuxtPlugin(() => {
  try {
    const personal = usePersonalisation();
    const account = useAccount();
    personal.load();
    useSupabaseClient().auth.onAuthStateChange((event) => {
      if (event !== 'SIGNED_OUT') return;
      personal.resetAccount();
      // The name and photo kept for a quick start belong to the account that just signed out.
      account.forget();
    });
  } catch (error) {
    if (import.meta.dev) console.error('The look of PAVE could not be applied', error);
  }
});
