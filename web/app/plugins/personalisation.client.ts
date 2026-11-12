// Puts the chosen theme colour and text size on the page before it shows, on every page.
export default defineNuxtPlugin(() => {
  usePersonalisation().load();
});
