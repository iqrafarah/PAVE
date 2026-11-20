/** The search dialog is shared: the chat history button and the Cmd/Ctrl+K shortcut open the same one. */
export function useAylaSearch() {
  const isOpen = useState('ayla-search-open', () => false);
  return {
    isOpen,
    open: () => { isOpen.value = true; },
    close: () => { isOpen.value = false; },
    toggle: () => { isOpen.value = !isOpen.value; },
  };
}
