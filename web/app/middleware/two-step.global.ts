const PUBLIC_PATHS = ['/login', '/confirm'];
const TWO_STEP_PATH = '/two-step';

export default defineNuxtRouteMiddleware(async (to) => {
  if (PUBLIC_PATHS.includes(to.path)) return;

  const session = useSupabaseSession();
  if (!session.value) return;

  const isComplete = await useTwoStepVerification().isTwoStepComplete();
  const isOnTwoStepPage = to.path === TWO_STEP_PATH;

  if (!isComplete && !isOnTwoStepPage) return navigateTo(TWO_STEP_PATH);
  if (isComplete && isOnTwoStepPage) return navigateTo('/');
});
