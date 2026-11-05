<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const { user, signIn, resendVerificationEmail } = useAuth();

const email = ref('');
const password = ref('');
const errorMessage = ref('');
const infoMessage = ref('');
const isLoading = ref(false);
const isEmailUnverified = ref(false);

watch(
  user,
  () => {
    if (user.value) navigateTo('/');
  },
  { immediate: true },
);

async function handleSubmit() {
  errorMessage.value = '';
  infoMessage.value = '';
  isEmailUnverified.value = false;
  isLoading.value = true;

  const { error } = await signIn(email.value, password.value);

  isLoading.value = false;
  if (!error) return;

  if (error.code === 'email_not_confirmed') {
    isEmailUnverified.value = true;
    errorMessage.value = 'Please verify your email before signing in.';
    return;
  }
  errorMessage.value = 'Incorrect email or password.';
}

async function handleResend() {
  const { error } = await resendVerificationEmail(email.value);
  infoMessage.value = error
    ? 'We could not send the email. Please try again later.'
    : 'Verification email sent again.';
}
</script>

<template>
  <AuthCard
    eyebrow="Sign in"
    title="Welcome to PAVE"
    description="Sign in to continue building your personal portfolio."
  >
    <form class="mt-8" @submit.prevent="handleSubmit">
      <AuthEmailInput id="email" v-model="email" />
      <AuthPasswordInput
        id="password"
        v-model="password"
        class="mt-5"
        label="Password"
        placeholder="Enter your password"
        autocomplete="current-password"
      />

      <div class="mt-6 flex justify-end">
        <NuxtLink
          to="/forgot-password"
          class="text-sm font-medium text-brand focus-visible:outline-2 focus-visible:outline-brand"
        >
          Forgot password?
        </NuxtLink>
      </div>

      <p v-if="errorMessage" role="alert" class="mt-4 text-sm text-danger">
        {{ errorMessage }}
      </p>
      <p v-if="infoMessage" class="mt-4 text-sm text-brand">
        {{ infoMessage }}
      </p>

      <AuthPrimaryButton type="submit" :disabled="isLoading">
        {{ isLoading ? 'Signing in...' : 'Sign in' }}
      </AuthPrimaryButton>

      <button
        v-if="isEmailUnverified"
        type="button"
        class="mt-3 text-sm font-medium text-brand underline"
        @click="handleResend"
      >
        Resend verification email
      </button>
    </form>

    <AuthInfoBox title="Your account is provided">
      Use the account supplied by your organization. If you don’t have your
      details, contact IT support.
    </AuthInfoBox>
  </AuthCard>
</template>
