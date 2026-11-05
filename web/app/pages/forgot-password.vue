<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const RATE_LIMIT_STATUS = 429;
const RATE_LIMIT_MESSAGE =
  'You requested a code very recently. Wait 60 seconds and try again.';
const SEND_ERROR_MESSAGE =
  'We could not send the code. Try again later or contact IT support.';
const INVALID_CODE_MESSAGE =
  'This code is invalid or has expired. Check the code or request a new one.';

const { sendPasswordResetCode, verifyPasswordResetCode } = useAuth();

const email = ref('');
const code = ref('');
const isCodeSent = ref(false);
const isBusy = ref(false);
const sendError = ref('');
const codeError = ref('');
const resendMessage = ref('');

const sentDescription = computed(
  () =>
    `If an account exists for ${email.value}, we sent a code to reset your password.`,
);
const verifyButtonLabel = computed(() => {
  if (isBusy.value) return 'Checking...';
  if (codeError.value) return 'Try again';
  return 'Verify code';
});

function getSendErrorMessage(status?: number) {
  return status === RATE_LIMIT_STATUS ? RATE_LIMIT_MESSAGE : SEND_ERROR_MESSAGE;
}

async function sendCode() {
  sendError.value = '';
  isBusy.value = true;
  const { error } = await sendPasswordResetCode(email.value);
  isBusy.value = false;

  if (!error) return true;

  if (import.meta.dev) console.error('Sending reset code failed', error);
  sendError.value = getSendErrorMessage(error.status);
  return false;
}

async function handleEmailSubmit() {
  isCodeSent.value = await sendCode();
}

async function handleResend() {
  resendMessage.value = '';
  const isSent = await sendCode();
  if (isSent) resendMessage.value = 'We sent a new code.';
}

async function handleCodeSubmit() {
  codeError.value = '';
  isBusy.value = true;
  const { error } = await verifyPasswordResetCode(email.value, code.value);
  isBusy.value = false;

  if (error) {
    codeError.value = INVALID_CODE_MESSAGE;
    return;
  }
  await navigateTo('/set-password');
}
</script>

<template>
  <AuthCard
    v-if="!isCodeSent"
    eyebrow="Password recovery"
    title="Forgot your password?"
    description="Enter your organization email and we’ll send you a code to reset your password."
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
          d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75"
        />
      </svg>
    </template>

    <form class="mt-8" @submit.prevent="handleEmailSubmit">
      <AuthEmailInput id="email" v-model="email" />
      <p v-if="sendError" role="alert" class="mt-4 text-sm text-danger">
        {{ sendError }}
      </p>
      <AuthPrimaryButton type="submit" :disabled="isBusy">
        {{ isBusy ? 'Sending...' : 'Send code' }}
      </AuthPrimaryButton>
    </form>

    <p class="mt-4 text-sm text-muted">
      Use the email linked to your organization-provided PAVE account.
    </p>

    <AuthBackToLogin @click="navigateTo('/login')" />
  </AuthCard>

  <AuthCard
    v-else
    eyebrow="Password recovery"
    title="Check your inbox"
    :description="sentDescription"
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
          d="M2.25 13.5h3.86a2.25 2.25 0 0 1 2.012 1.244l.256.512a2.25 2.25 0 0 0 2.013 1.244h3.218a2.25 2.25 0 0 0 2.013-1.244l.256-.512a2.25 2.25 0 0 1 2.013-1.244h3.859m-19.5.338V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18v-4.162c0-.224-.034-.447-.1-.661L19.24 5.338a2.25 2.25 0 0 0-2.15-1.588H6.911a2.25 2.25 0 0 0-2.15 1.588L2.35 13.177a2.25 2.25 0 0 0-.1.661Z"
        />
      </svg>
    </template>

    <form @submit.prevent="handleCodeSubmit">
      <AuthCodeInput
        id="reset-code"
        v-model="code"
        hint="Enter the code from the email."
        :error="codeError"
      />
      <AuthPrimaryButton type="submit" :disabled="isBusy">
        {{ verifyButtonLabel }}
      </AuthPrimaryButton>
    </form>

    <AuthInfoBox title="Can’t find the email?">
      Allow a few minutes and check your spam or junk folder. If it still hasn’t
      arrived, request a new code.
    </AuthInfoBox>

    <button
      type="button"
      :disabled="isBusy"
      class="mt-4 text-sm font-medium text-brand underline focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60"
      @click="handleResend"
    >
      Send a new code
    </button>
    <p v-if="resendMessage" role="status" class="mt-2 text-sm text-brand">
      {{ resendMessage }}
    </p>
    <p v-if="sendError" role="alert" class="mt-2 text-sm text-danger">
      {{ sendError }}
    </p>

    <p class="mt-4 text-sm text-muted">
      For your privacy, we don’t confirm whether an email address has a PAVE
      account.
    </p>

    <AuthBackToLogin @click="navigateTo('/login')" />
  </AuthCard>
</template>
