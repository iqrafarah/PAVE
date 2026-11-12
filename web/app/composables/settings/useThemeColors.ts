/** Canvas drawings need their palette refreshed when an account theme arrives after mount. */
export function useThemeColors(update: (styles: CSSStyleDeclaration) => void) {
  const personal = usePersonalisation();
  onMounted(() => {
    watch(
      () => [personal.state.value.theme, personal.state.value.customColor],
      () => update(getComputedStyle(document.documentElement)),
      { immediate: true, flush: 'post' },
    );
  });
}
