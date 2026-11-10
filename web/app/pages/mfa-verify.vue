<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const { isPasswordReset, signOut } = useAuth();
const { verifyCode } = useMfa();

const code = ref('');
const errorMessage = ref('');
const isVerifying = ref(false);

const eyebrow = computed(() =>
  isPasswordReset.value ? 'Wachtwoord herstellen' : 'Tweestapsverificatie',
);
const description = computed(() =>
  isPasswordReset.value
    ? 'Voor je account staat tweestapsverificatie aan. Neem de code over uit je authenticator-app, niet uit je mail. Daarna kies je een nieuw wachtwoord.'
    : 'Open je authenticator-app en neem de code van 6 cijfers voor PAVE over. Je krijgt hem niet per mail.',
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
    title="Vul de code uit je authenticator-app in"
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
          d="M10.5 1.5H8.25A2.25 2.25 0 0 0 6 3.75v16.5a2.25 2.25 0 0 0 2.25 2.25h7.5A2.25 2.25 0 0 0 18 20.25V3.75a2.25 2.25 0 0 0-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
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

    <AuthInfoBox title="Kun je niet bij de app?">
      Neem contact op via <AuthSupportLink />.
    </AuthInfoBox>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
