import type { PaveLanguage, PaveTranslationTable } from '~/utils/settings/language';

// Shows PAVE in the language of Instellingen › Taal. The texts in the code are Dutch; like iOS (PaveLocalizedViews),
// the translation happens where a text is shown: every text on the page, and the attributes people hear or read
// (placeholder, title, aria-label, alt), is looked up in the table, also when Vue changes it later. What people made
// themselves (chats, evidence, e-mail, names) is marked translate="no" and stays as it is. A text that is not in the
// table stays Dutch. Dutch again puts every original text back.

const ATTRIBUTES = ['placeholder', 'title', 'aria-label', 'alt', 'aria-placeholder', 'aria-roledescription'];
const SKIPPED = 'script, style, textarea, code, pre, [translate="no"], [contenteditable="true"]';

interface Shown {
  source: string;
  shown: string;
}

export default defineNuxtPlugin((nuxtApp) => {
  const language = useLanguage();
  const texts = new WeakMap<Text, Shown>();
  const attributes = new WeakMap<Element, Map<string, Shown>>();
  let table: PaveTranslationTable | null = null;
  let observer: MutationObserver | null = null;

  function translated(source: string) {
    if (!table) return source;
    const trimmed = source.trim();
    if (!trimmed || !/\p{L}/u.test(trimmed)) return source;
    const result = table.translate(trimmed);
    return result === trimmed ? source : source.replace(trimmed, result);
  }

  /** The original is what Vue last wrote: a value that differs from what we showed is a new original. */
  function update(current: string, known: Shown | undefined, write: (value: string) => void): Shown {
    const entry = known && current === known.shown ? known : { source: current, shown: current };
    const next = translated(entry.source);
    if (next !== current) write(next);
    entry.shown = next;
    return entry;
  }

  function isSkipped(element: Element | null) {
    return !element || Boolean(element.closest(SKIPPED));
  }

  function translateText(node: Text) {
    if (isSkipped(node.parentElement)) return;
    texts.set(node, update(node.nodeValue ?? '', texts.get(node), (value) => (node.nodeValue = value)));
  }

  function translateAttribute(element: Element, name: string) {
    const current = element.getAttribute(name);
    if (current === null || isSkipped(element)) return;
    const known = attributes.get(element) ?? new Map<string, Shown>();
    known.set(name, update(current, known.get(name), (value) => element.setAttribute(name, value)));
    attributes.set(element, known);
  }

  function translateElement(element: Element) {
    for (const name of ATTRIBUTES) if (element.hasAttribute(name)) translateAttribute(element, name);
  }

  function translateTree(root: Node) {
    if (root.nodeType === Node.TEXT_NODE) {
      translateText(root as Text);
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE) return;
    const element = root as Element;
    if (element.matches(SKIPPED)) return;
    translateElement(element);
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT, {
      acceptNode: (node) =>
        node.nodeType === Node.ELEMENT_NODE && (node as Element).matches(SKIPPED) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT,
    });
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (node.nodeType === Node.TEXT_NODE) translateText(node as Text);
      else translateElement(node as Element);
    }
  }

  function watchPage() {
    if (observer) return;
    observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === 'characterData') translateText(mutation.target as Text);
        else if (mutation.type === 'attributes' && mutation.attributeName) translateAttribute(mutation.target as Element, mutation.attributeName);
        else mutation.addedNodes.forEach(translateTree);
      }
    });
    observer.observe(document.documentElement, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: ATTRIBUTES,
    });
  }

  async function show(next: PaveLanguage) {
    const nextTable = next === 'nl' ? null : await translationTable(next);
    // Another language was picked while this one was loading.
    if (language.state.value.language !== next) return;
    table = nextTable;
    translateTree(document.documentElement);
    watchPage();
  }

  // After hydration, so Vue finds the page as the server made it.
  nuxtApp.hook('app:mounted', async () => {
    await language.load();
    watch(
      () => language.state.value.language,
      (next) => show(next),
      { immediate: true },
    );
  });

  // Signing in can bring the account's language.
  const user = useSupabaseUser();
  watch(
    () => user.value?.sub,
    (id, previous) => {
      if (id && id !== previous) language.load();
    },
  );
});
