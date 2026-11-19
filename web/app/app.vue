<script setup lang="ts">
const { resolved, startClock } = useDisplayMode();
// Before the page is interactive, Auto picks the right look from the clock so there is no light flash at night.
const AUTO_SCRIPT = "(function(){try{var m=document.cookie.match(/pave-display-mode=(\\w+)/);if(m&&m[1]!=='auto')return;var h=new Date().getHours();if(h>=19||h<7)document.documentElement.setAttribute('data-display-mode','dark')}catch(e){}})()";
useHead(() => ({
  htmlAttrs: { 'data-display-mode': resolved.value },
  script: [{ innerHTML: AUTO_SCRIPT, tagPosition: 'head' }],
}));
onMounted(startClock);
</script>

<template>
  <div>
    <NuxtRouteAnnouncer />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>
