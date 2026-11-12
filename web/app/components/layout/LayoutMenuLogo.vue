<script setup lang="ts">
// The PAVE logo at the top left on small screens, where the rail is hidden: the only way to open the menu
// (iOS: the menu button at the top left). On wider screens the rail with its own PAVE logo is always there.
const { openMenu } = useMainMenu();
</script>

<template>
  <button
    type="button"
    :aria-label="MENU_LABEL"
    aria-haspopup="dialog"
    class="mr-1 flex h-10 w-11.5 shrink-0 items-center justify-center rounded-md bg-tint hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-brand md:hidden"
    data-menu-opener
    @click="openMenu"
  >
    <img src="/images/ayla/logo-mark.svg" alt="" width="34" height="18" />
  </button>
</template>
