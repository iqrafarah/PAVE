// Below this width the chat history is a drawer and the rail is hidden (Tailwind md).
const WIDE_SCREEN_QUERY = '(min-width: 48rem)';
const STORAGE_KEY = 'ayla-panel';

/**
 * Whether the chat history is shown. On a wide screen it is a panel next to the chat that the PAVE logo in the rail
 * opens and closes; it stays the way the user left it while moving between pages and after a reload (kept in this
 * browser). On small screens it opens as a drawer from "Chats" in the menu.
 */
export function useAylaPanel() {
  const isDrawerOpen = useState('ayla-panel-drawer-open', () => false);
  const isCollapsed = useState('ayla-panel-collapsed', () => false);

  function remember() {
    try {
      localStorage.setItem(STORAGE_KEY, isCollapsed.value ? 'closed' : 'open');
    } catch {
      // Storage is blocked: the choice works until the page is closed.
    }
  }

  /** Puts the panel back the way the user left it. Called once the page is in the browser. */
  function restore() {
    try {
      isCollapsed.value = localStorage.getItem(STORAGE_KEY) === 'closed';
    } catch {
      // Storage is blocked: the panel starts open.
    }
  }

  function setCollapsed(isNowCollapsed: boolean) {
    isCollapsed.value = isNowCollapsed;
    remember();
  }

  function openPanel() {
    if (window.matchMedia(WIDE_SCREEN_QUERY).matches) setCollapsed(false);
    else isDrawerOpen.value = true;
  }

  /** The PAVE logo in the rail: opens or closes the chat history, and goes to Ayla first where there are no chats. */
  async function toggleFromLogo(hasChats: boolean) {
    if (hasChats) {
      setCollapsed(!isCollapsed.value);
      return;
    }
    setCollapsed(false);
    await navigateTo('/');
  }

  function closeDrawer() {
    isDrawerOpen.value = false;
  }

  return { isDrawerOpen, isCollapsed, restore, setCollapsed, openPanel, toggleFromLogo, closeDrawer };
}
