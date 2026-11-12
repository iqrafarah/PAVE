// The last line of defence. A failure in one part (a click handler, a watcher, a promise nobody waited for) is noted
// and stays in that part, so the rest of the site keeps working instead of the whole screen going blank. Failures
// while a page is drawn are caught closer by, in the layout (NuxtErrorBoundary), and by error.vue.
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.hook('vue:error', (error, _instance, info) => {
    console.error(`PAVE: something went wrong (${info})`, error);
  });
  window.addEventListener('unhandledrejection', (event) => {
    console.error('PAVE: a request or action failed without being handled', event.reason);
    event.preventDefault();
  });
});
