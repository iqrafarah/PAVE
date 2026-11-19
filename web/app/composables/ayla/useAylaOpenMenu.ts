// While a ⋯ menu is open the chat list holds still: a reload or the clock moving a row would close the menu under
// the pointer. Updates that come in meanwhile are applied right after it closes.
export function useAylaOpenMenu() {
  const openCount = useState<number>('ayla-open-menus', () => 0);
  const hasPendingReload = useState<boolean>('ayla-open-menu-pending', () => false);
  return { openCount, hasPendingReload };
}
