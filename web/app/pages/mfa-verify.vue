<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const INVALID_CODE_MESSAGE =
  'This code is invalid or has expired. Use the latest code in your authenticator app and try again.';
const LOAD_ERROR_MESSAGE =
  'We could not load your two-step verification. Please try again.';

const { signOut } = useAuth();
const { getVerifiedFactorId, verifyTotp } = useMfa();

const code = ref('');
const errorMessage = ref('');
const isVerifying = ref(false);

const buttonLabel = computed(() => {
  if (isVerifying.value) return 'Verifying...';
  if (errorMessage.value) return 'Try again';
  return 'Verify';
});

async function verify() {
  const { data: factorId, error: factorError } = await getVerifiedFactorId();
  if (factorError || !factorId) return LOAD_ERROR_MESSAGE;

  const { error } = await verifyTotp(factorId, code.value);
  if (error) return INVALID_CODE_MESSAGE;
  return '';
}

async function handleSubmit() {
  isVerifying.value = true;
  errorMessage.value = await verify();
  isVerifying.value = false;

  if (!errorMessage.value) await navigateTo('/');
}
</script>

<template>
  <AuthCard
    eyebrow="Two-step verification"
    title="Verify your identity"
    description="Open your authenticator app and enter the 6-digit code for your PAVE account."
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
          d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z"
        />
      </svg>
    </template>

    <form @submit.prevent="handleSubmit">
      <AuthCodeInput
        id="verification-code"
        v-model="code"
        hint="Enter the code shown in your authenticator app."
        :error="errorMessage"
      />
      <AuthPrimaryButton type="submit" :disabled="isVerifying">
        {{ buttonLabel }}
      </AuthPrimaryButton>
    </form>

    <AuthInfoBox title="Use your authenticator app">
      Your code comes from your authenticator app, not by email or SMS. Can’t
      access the app? Contact IT support.
    </AuthInfoBox>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
