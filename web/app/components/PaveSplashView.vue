<template>
  <div class="splash" role="status" aria-label="PAVE wordt geladen">
    <div class="splash__gradient" />
    <div class="splash__wordmark" aria-hidden="true">
      <img
        v-for="(letter, index) in ['P', 'A', 'V', 'E']"
        :key="letter"
        :src="`/splash/PaveLetter${letter}.svg`"
        :style="{ animationDelay: `${index * 0.12}s` }"
        alt=""
      >
    </div>
  </div>
</template>

<style scoped>
.splash {
  position: fixed;
  inset: 0;
  z-index: 9999;
  display: grid;
  place-items: center;
  background: #f9f9f9;
}

.splash__gradient {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom left, #355d4c 0%, #f9f9f9 25%, #f9f9f9 74.038%, #355d4c 100%);
  animation: fade-in 0.35s ease-out both;
}

.splash__wordmark {
  position: relative;
  width: 44.5%;
  aspect-ratio: 835 / 361;
}

.splash__wordmark img {
  position: absolute;
  width: 100%;
  height: 100%;
  animation: reveal-letter 0.5s cubic-bezier(0.16, 1, 0.3, 1) both;
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes reveal-letter {
  from { opacity: 0; transform: translateY(56px); }
  to { opacity: 1; transform: translateY(0); }
}

@media (prefers-reduced-motion: reduce) {
  .splash__wordmark img {
    animation: fade-in 0.3s ease-out both;
    animation-delay: 0s !important;
  }
}
</style>
