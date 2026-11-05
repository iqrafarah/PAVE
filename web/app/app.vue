<script setup>
const showSplash = ref(true)
let splashTimer

onMounted(() => {
  splashTimer = window.setTimeout(() => { showSplash.value = false }, 1500)
})

onUnmounted(() => window.clearTimeout(splashTimer))
</script>

<template>
  <div>
    <NuxtRouteAnnouncer />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
    <PaveSplashView v-if="showSplash" />
  </div>
</template>
