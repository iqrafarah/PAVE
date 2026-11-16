<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const { signOut } = useAuth();

const errorMessage = ref('');

async function handleBackToLogin() {
  errorMessage.value = '';
  const { error } = await signOut();
  if (error) errorMessage.value = getAuthErrorMessage(error);
}
</script>

<template>
  <AuthCard
    eyebrow="Wachtwoord hersteld"
    title="Wachtwoord gewijzigd"
    description="Je nieuwe wachtwoord is opgeslagen. Je kunt er nu mee inloggen bij PAVE."
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

    <AuthInfoBox title="Tweestapsverificatie staat nog aan">
      Als je je wachtwoord herstelt, verandert je extra beveiliging niet. Houd je
      authenticator-app bij de hand als je inlogt.
    </AuthInfoBox>

    <p v-if="errorMessage" role="alert" class="mt-4 text-sm text-danger">
      {{ errorMessage }}
    </p>
    <AuthPrimaryButton @click="handleBackToLogin">
      Terug naar inloggen
    </AuthPrimaryButton>
  </AuthCard>
</template>
