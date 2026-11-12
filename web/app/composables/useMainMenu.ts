/** The menu drawer on small screens (iOS MainMenuDrawer). On wider screens the rail is always on screen instead. */
export function useMainMenu() {
  const isMenuOpen = useState('pave-menu-open', () => false);

  function openMenu() {
    isMenuOpen.value = true;
  }

  function closeMenu() {
    isMenuOpen.value = false;
  }

  return { isMenuOpen, openMenu, closeMenu };
}
