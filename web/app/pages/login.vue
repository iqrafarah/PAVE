<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const { user, signIn, resendVerificationEmail } = useAuth();

const email = ref('');
const password = ref('');
const errorMessage = ref('');
const infoMessage = ref('');
const isLoading = ref(false);
const isEmailUnverified = ref(false);
const isPasswordVisible = ref(false);

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
  infoMessage.value = error ? error.message : 'Verification email sent again.';
}
</script>

<template>
  <AuthCard
    eyebrow="Sign in"
    title="Welcome to PAVE"
    description="Sign in to continue building your personal portfolio."
  >
    <form class="mt-8" @submit.prevent="handleSubmit">
      <label for="email" class="block text-sm font-medium text-ink"
        >Email address</label
      >
      <input
        id="email"
        v-model="email"
        type="email"
        required
        autocomplete="email"
        placeholder="Your organization email"
        class="mt-2 h-13 w-full rounded-lg border border-line px-3.5 text-base text-ink placeholder:text-muted focus-visible:outline-2 focus-visible:outline-brand"
      />

      <label for="password" class="mt-5 block text-sm font-medium text-ink"
        >Password</label
      >
      <div class="relative mt-2">
        <input
          id="password"
          v-model="password"
          :type="isPasswordVisible ? 'text' : 'password'"
          required
          autocomplete="current-password"
          placeholder="Enter your password"
          class="h-13 w-full rounded-lg border border-line pl-3.5 pr-24 text-base text-ink placeholder:text-muted focus-visible:outline-2 focus-visible:outline-brand"
        />
        <button
          type="button"
          class="absolute right-3.5 top-1/2 flex -translate-y-1/2 items-center gap-2 text-sm font-medium text-ink focus-visible:outline-2 focus-visible:outline-brand"
          @click="isPasswordVisible = !isPasswordVisible"
        >
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
              d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"
            />
          </svg>
          {{ isPasswordVisible ? 'Hide' : 'Show' }}
        </button>
      </div>

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

    <div class="mt-6 flex gap-3 text-sm text-ink">
      <svg
        class="size-5 shrink-0"
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
      <p>
        Two-step verification is required. After your password, enter a code
        from your authenticator app.
      </p>
    </div>

    <AuthInfoBox title="Your account is provided">
      Use the account supplied by your organization. If you don’t have your
      details, contact IT support.
    </AuthInfoBox>
  </AuthCard>
</template>
