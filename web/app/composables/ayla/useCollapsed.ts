/**
 * Whether a group in the chat history is folded, remembered in this browser (like the folders of ChatGPT).
 * Without a key the group cannot be folded. Storage that is blocked just means it opens again next time.
 */
export function useCollapsed(key: string | undefined) {
  const isCollapsed = ref(false);
  const storageKey = key ? `pave-collapsed-${key}` : null;

  onMounted(() => {
    if (!storageKey) return;
    try {
      isCollapsed.value = localStorage.getItem(storageKey) === '1';
    } catch {
      isCollapsed.value = false;
    }
  });

  watch(isCollapsed, (value) => {
    if (!storageKey) return;
    try {
      localStorage.setItem(storageKey, value ? '1' : '0');
    } catch {
      // Not remembered, still folds.
    }
  });

  return isCollapsed;
}
