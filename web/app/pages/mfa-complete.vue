<script setup lang="ts">
definePageMeta({ layout: 'auth' });
</script>

<template>
  <AuthCard
    eyebrow="Setup complete"
    title="You’re all set"
    description="Two-step verification is now enabled for your PAVE account."
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

    <AuthInfoBox title="Your portfolio has extra protection">
      Next time you sign in, use your password and a code from your
      authenticator app. Keep the app on your phone.
    </AuthInfoBox>

    <AuthPrimaryButton @click="navigateTo('/')">Continue to PAVE</AuthPrimaryButton>
  </AuthCard>
</template>
