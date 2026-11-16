<script setup lang="ts">
import type { AuthErrorLike } from '~/utils/auth/authErrors';

definePageMeta({ layout: 'auth' });

const EMAIL_NOT_CONFIRMED_CODE = 'email_not_confirmed';

const { signIn, resendVerificationEmail } = useAuth();
const { getMfaStatus } = useMfa();

const email = ref('');
const password = ref('');
const errorMessage = ref('');
const infoMessage = ref('');
const isLoading = ref(false);
const isEmailUnverified = ref(false);

async function handleSubmit() {
  errorMessage.value = '';
  infoMessage.value = '';
  isEmailUnverified.value = false;
  isLoading.value = true;

  const { error } = await signIn(email.value.trim(), password.value);
  if (error) {
    isLoading.value = false;
    showSignInError(error);
    return;
  }

  const { data: status } = await getMfaStatus();
  await navigateTo(getMfaPath(status));
  isLoading.value = false;
}

function showSignInError(error: AuthErrorLike) {
  if (error.code === EMAIL_NOT_CONFIRMED_CODE) {
    isEmailUnverified.value = true;
    errorMessage.value =
      'Bevestig eerst je e-mailadres. Kijk in je mail voor de bevestigingslink.';
    return;
  }
  errorMessage.value = getAuthErrorMessage(error);
}

async function handleResend() {
  const { error } = await resendVerificationEmail(email.value.trim());
  infoMessage.value = error
    ? getAuthErrorMessage(error)
    : 'We hebben de bevestigingsmail opnieuw verstuurd.';
}
</script>

<template>
  <AuthCard
    title="Welkom bij PAVE"
    :description="LOGIN_INSTRUCTION"
  >

    <form @submit.prevent="handleSubmit">
      <AuthEmailInput id="email" v-model="email" />
      <AuthPasswordInput
        id="password"
        v-model="password"
        class="mt-5"
        label="Wachtwoord"
        placeholder="Vul je wachtwoord in"
        autocomplete="current-password"
      />

      <div class="mt-3 flex justify-end">
        <NuxtLink
          to="/forgot-password"
          class="text-sm font-medium text-brand focus-visible:outline-2 focus-visible:outline-brand"
        >
          Wachtwoord vergeten?
        </NuxtLink>
      </div>

      <p v-if="errorMessage" role="alert" class="mt-4 text-sm text-danger">
        {{ errorMessage }}
      </p>
      <p v-if="infoMessage" class="mt-4 text-sm text-brand">
        {{ infoMessage }}
      </p>

      <AuthPrimaryButton type="submit" :disabled="isLoading">
        {{ isLoading ? 'Bezig met inloggen...' : 'Inloggen' }}
      </AuthPrimaryButton>

      <button
        v-if="isEmailUnverified"
        type="button"
        class="mt-3 text-sm font-medium text-brand underline"
        @click="handleResend"
      >
        Bevestigingsmail opnieuw versturen
      </button>
    </form>

    <p class="mt-6 text-sm text-muted">
      Heb je geen account of lukt inloggen niet? Mail naar <AuthSupportLink />.
    </p>
  </AuthCard>
</template>
