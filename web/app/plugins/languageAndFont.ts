// The language and the typeface on the page, on the server already, from the cookies the browser keeps: <html lang>
// (for screen readers and spelling) and data-font (main.css). The texts themselves are translated in the browser
// (plugins/language.client.ts).
export default defineNuxtPlugin(() => {
  useFontStyle();
  const language = useLanguage();
  useHead(() => ({ htmlAttrs: { lang: language.state.value.language } }));
});
