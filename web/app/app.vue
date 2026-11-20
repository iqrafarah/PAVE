<script setup lang="ts">
const { resolved, watchSystem } = useDisplayMode();
// Before the page is interactive, Auto picks the look of the device setting so there is no light flash at night.
const AUTO_SCRIPT = "(function(){try{var m=document.cookie.match(/pave-display-mode=(\\w+)/);if(m&&m[1]!=='auto')return;if(window.matchMedia('(prefers-color-scheme: dark)').matches)document.documentElement.setAttribute('data-display-mode','dark')}catch(e){}})()";
useHead(() => ({
  htmlAttrs: { 'data-display-mode': resolved.value },
  script: [{ innerHTML: AUTO_SCRIPT, tagPosition: 'head' }],
}));
onMounted(watchSystem);
</script>

<template>
  <div>
    <NuxtRouteAnnouncer />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>
