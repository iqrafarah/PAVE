<script setup lang="ts">
import type { MfaStatus } from '~/utils/mfaRoutes';

definePageMeta({ layout: 'auth' });

const { sendPasswordResetCode, verifyPasswordResetCode } = useAuth();
const { getMfaStatus } = useMfa();

const email = ref('');
const code = ref('');
const isCodeSent = ref(false);
const isBusy = ref(false);
const sendError = ref('');
const codeError = ref('');
const resendMessage = ref('');

const verifyButtonLabel = computed(() => {
  if (isBusy.value) return 'Bezig met controleren...';
  if (codeError.value) return 'Opnieuw proberen';
  return 'Code bevestigen';
});

async function sendCode() {
  sendError.value = '';
  isBusy.value = true;
  const { error } = await sendPasswordResetCode(email.value);
  isBusy.value = false;

  if (!error) return true;

  sendError.value = getAuthErrorMessage(error);
  return false;
}

async function handleEmailSubmit() {
  isCodeSent.value = await sendCode();
}

async function handleResend() {
  resendMessage.value = '';
  const isSent = await sendCode();
  if (isSent) resendMessage.value = 'We hebben een nieuwe code gestuurd.';
}

async function handleCodeSubmit() {
  codeError.value = '';
  isBusy.value = true;
  const { error } = await verifyPasswordResetCode(email.value, code.value);
  if (error) {
    isBusy.value = false;
    codeError.value = getAuthErrorMessage(error);
    code.value = '';
    return;
  }

  const { data: status } = await getMfaStatus();
  await navigateTo(getPathAfterResetCode(status));
  isBusy.value = false;
}

function getPathAfterResetCode(status: MfaStatus | null) {
  if (status === 'needs-setup') return SET_PASSWORD_PATH;
  return MFA_VERIFY_PATH;
}
</script>

<template>
  <AuthCard
    v-if="!isCodeSent"
    eyebrow="Wachtwoord herstellen"
    title="Wachtwoord vergeten?"
    description="Vul je e-mailadres in. Dan sturen we je een code om een nieuw wachtwoord te kiezen."
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
        {{ isBusy ? 'Bezig met versturen...' : 'Code versturen' }}
      </AuthPrimaryButton>
    </form>

    <AuthBackToLogin @click="navigateTo('/login')" />
  </AuthCard>

  <AuthCard
    v-else
    eyebrow="Wachtwoord herstellen"
    title="Check je inbox"
    :description="RESET_REQUESTED_MESSAGE"
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
        hint="Vul de code uit de e-mail in."
        :error="codeError"
      />
      <AuthPrimaryButton type="submit" :disabled="isBusy">
        {{ verifyButtonLabel }}
      </AuthPrimaryButton>
    </form>

    <AuthInfoBox title="Geen e-mail gekregen?">
      Wacht een paar minuten en kijk ook in je map met spam of ongewenste
      e-mail. Nog steeds niets? Vraag een nieuwe code aan.
    </AuthInfoBox>

    <button
      type="button"
      :disabled="isBusy"
      class="mt-4 text-sm font-medium text-brand underline focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60"
      @click="handleResend"
    >
      Nieuwe code versturen
    </button>
    <p v-if="resendMessage" role="status" class="mt-2 text-sm text-brand">
      {{ resendMessage }}
    </p>
    <p v-if="sendError" role="alert" class="mt-2 text-sm text-danger">
      {{ sendError }}
    </p>

    <p class="mt-4 text-sm text-muted">
      We laten nooit zien of een e-mailadres een PAVE-account heeft. Zo blijven
      je gegevens veilig.
    </p>

    <AuthBackToLogin @click="navigateTo('/login')" />
  </AuthCard>
</template>
