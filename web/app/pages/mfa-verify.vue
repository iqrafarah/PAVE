<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const route = useRoute();
const { signOut } = useAuth();
const { verifyCode } = useMfa();

const code = ref('');
const errorMessage = ref('');
const isVerifying = ref(false);

const isPasswordReset = computed(() => route.query.next === SET_PASSWORD_PATH);
const eyebrow = computed(() =>
  isPasswordReset.value ? 'Wachtwoord herstellen' : 'Tweestapsverificatie',
);
const description = computed(() =>
  isPasswordReset.value
    ? 'Voor je account staat tweestapsverificatie aan. Vul de code uit je authenticator-app in. Daarna kies je een nieuw wachtwoord.'
    : 'Open je authenticator-app en vul de code van 6 cijfers voor je PAVE-account in.',
);
const nextPath = computed(() =>
  isPasswordReset.value ? SET_PASSWORD_PATH : HOME_PATH,
);
const buttonLabel = computed(() => {
  if (isVerifying.value) return 'Bezig met controleren...';
  if (errorMessage.value) return 'Opnieuw proberen';
  return 'Bevestigen';
});

async function handleSubmit() {
  errorMessage.value = '';
  isVerifying.value = true;
  const { error } = await verifyCode(code.value);
  isVerifying.value = false;

  if (error) {
    errorMessage.value = getAuthErrorMessage(error);
    code.value = '';
    return;
  }
  await navigateTo(nextPath.value);
}
</script>

<template>
  <AuthCard
    :eyebrow="eyebrow"
    title="Bevestig dat jij het bent"
    :description="description"
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
        hint="Vul de code in die je authenticator-app nu laat zien."
        :error="errorMessage"
      />
      <AuthPrimaryButton type="submit" :disabled="isVerifying">
        {{ buttonLabel }}
      </AuthPrimaryButton>
    </form>

    <AuthInfoBox title="Gebruik je authenticator-app">
      Je code komt uit je authenticator-app, niet via e-mail of sms. Kun je niet
      bij de app? Neem contact op via <AuthSupportLink />.
    </AuthInfoBox>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
