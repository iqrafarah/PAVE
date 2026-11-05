<script setup lang="ts">
definePageMeta({ layout: 'auth' });
</script>

<template>
  <AuthCard
    eyebrow="Instellen gelukt"
    title="Alles staat klaar"
    description="Tweestapsverificatie staat nu aan voor je PAVE-account."
  >
    <template #icon>
      <svg
        class="size-5"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
        />
      </svg>
    </template>

    <AuthInfoBox title="Je portfolio is extra beveiligd">
      Log je de volgende keer in? Gebruik dan je wachtwoord en een code uit je
      authenticator-app. Houd de app op je telefoon.
    </AuthInfoBox>

    <AuthPrimaryButton @click="navigateTo(HOME_PATH)">
      Verder naar PAVE
    </AuthPrimaryButton>
  </AuthCard>
</template>
