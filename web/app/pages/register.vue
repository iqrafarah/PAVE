<script setup lang="ts">
import type { PasswordFieldState } from '~/utils/auth/passwordRules';

definePageMeta({ layout: 'auth' });

const email = ref('');
const firstName = ref('');
const lastName = ref('');
const password = ref('');
const confirmation = ref('');
const hasLeftConfirmation = ref(false);

const rules = computed(() => getPasswordRules(password.value));
const isPasswordStrong = computed(() => rules.value.every((rule) => rule.isMet));
const doPasswordsMatch = computed(() => password.value === confirmation.value);
const canSubmit = computed(() => isPasswordStrong.value && doPasswordsMatch.value);
const passwordState = computed<PasswordFieldState>(() => (isPasswordStrong.value ? 'valid' : 'incomplete'));
const confirmationState = computed<PasswordFieldState>(() => (doPasswordsMatch.value ? 'valid' : 'incomplete'));
const confirmationStatus = computed(() => {
  if (doPasswordsMatch.value) return PASSWORDS_MATCH_MESSAGE;
  const areBothFilled = Boolean(password.value && confirmation.value);
  if (hasLeftConfirmation.value && areBothFilled) return PASSWORDS_NOT_EQUAL_MESSAGE;
  return '';
});

const { signUp, verifySignUpCode, resendVerificationEmail } = useAuth();
const { getMfaStatus } = useMfa();
const code = ref('');
const codeError = ref('');
const resendMessage = ref('');
const isVerifying = ref(false);
const errorMessage = ref('');
const isSaving = ref(false);
const isDone = ref(false);

async function handleSubmit() {
  if (!canSubmit.value) return;
  errorMessage.value = '';
  isSaving.value = true;
  const { error, hasSession, isExisting } = await signUp({
    email: email.value.trim(),
    password: password.value,
    firstName: firstName.value,
    lastName: lastName.value,
  });
  isSaving.value = false;
  if (error) {
    errorMessage.value = getAuthErrorMessage(error);
    return;
  }
  if (isExisting) {
    errorMessage.value = EMAIL_ALREADY_REGISTERED_MESSAGE;
    return;
  }
  if (hasSession) {
    await navigateTo(HOME_PATH);
    return;
  }
  isDone.value = true;
}

async function handleCodeSubmit() {
  codeError.value = '';
  isVerifying.value = true;
  const { error } = await verifySignUpCode(email.value.trim(), code.value);
  if (error) {
    isVerifying.value = false;
    codeError.value = getAuthErrorMessage(error);
    code.value = '';
    return;
  }
  const { data: status } = await getMfaStatus();
  await navigateTo(getMfaPath(status));
  isVerifying.value = false;
}

async function handleResend() {
  resendMessage.value = '';
  const { error } = await resendVerificationEmail(email.value.trim());
  if (error) codeError.value = getAuthErrorMessage(error);
  else resendMessage.value = EMAIL_CODE_RESENT_MESSAGE;
}

const FIELD_CLASS =
  'mt-2 h-13 w-full rounded-lg border border-line px-3.5 text-base text-ink placeholder:text-muted focus-visible:outline-2 focus-visible:outline-brand';
</script>

<template>
  <AuthEduidCard
    title="Maak je eduID aan"
    description="Vul je gegevens in om een account aan te maken."
  >
    <div v-if="isDone">
      <p class="text-sm text-muted">{{ getResetCodeSentMessage(maskEmail(email)) }}</p>
      <form class="mt-6" @submit.prevent="handleCodeSubmit">
        <AuthCodeInput
          id="signup-code"
          v-model="code"
          :label="EMAIL_CODE_LABEL"
          is-autofocused
          :error="codeError"
        />
        <AuthPrimaryButton type="submit" :disabled="isVerifying">
          {{ isVerifying ? 'Bezig met controleren...' : 'Code bevestigen' }}
        </AuthPrimaryButton>
      </form>
      <AuthInfoBox title="Geen e-mail gekregen?">
        Kijk ook in je map met spam of ongewenste e-mail. Nog steeds niets? Vraag een nieuwe code aan.
      </AuthInfoBox>
      <button
        type="button"
        class="mt-4 text-sm font-medium text-brand underline focus-visible:outline-2 focus-visible:outline-brand"
        @click="handleResend"
      >
        {{ RESEND_EMAIL_CODE_LABEL }}
      </button>
      <p v-if="resendMessage" role="status" class="mt-2 text-sm text-brand">{{ resendMessage }}</p>
    </div>

    <form v-else @submit.prevent="handleSubmit">
      <AuthEmailInput id="email" v-model="email" />
      <div class="mt-5">
        <label for="first-name" class="block text-sm font-medium text-ink">Voornaam</label>
        <input
          id="first-name"
          v-model="firstName"
          type="text"
          required
          autocomplete="given-name"
          :class="FIELD_CLASS"
        />
      </div>
      <div class="mt-5">
        <label for="last-name" class="block text-sm font-medium text-ink">Achternaam</label>
        <input
          id="last-name"
          v-model="lastName"
          type="text"
          required
          autocomplete="family-name"
          :class="FIELD_CLASS"
        />
      </div>

      <AuthPasswordInput
        id="new-password"
        v-model="password"
        class="mt-5"
        label="Wachtwoord"
        placeholder="Kies een wachtwoord"
        autocomplete="new-password"
        :state="passwordState"
        is-copy-blocked
      />
      <AuthPasswordRules :rules="rules" />
      <AuthPasswordInput
        id="confirm-password"
        v-model="confirmation"
        class="mt-5"
        label="Herhaal je wachtwoord"
        placeholder="Vul je wachtwoord nog een keer in"
        autocomplete="new-password"
        :state="confirmationState"
        :status="confirmationStatus"
        :hint="REPEAT_PASSWORD_HINT"
        is-copy-blocked
        is-paste-blocked
        @blur="hasLeftConfirmation = true"
      />

      <p v-if="errorMessage" role="alert" class="mt-4 text-sm text-danger">
        {{ errorMessage }}
      </p>

      <AuthPrimaryButton type="submit" :disabled="isSaving || !canSubmit">
        {{ isSaving ? 'Bezig met aanmaken...' : 'Account aanmaken' }}
      </AuthPrimaryButton>
    </form>

    <p class="mt-6 text-sm text-muted">
      Heb je al een eduID?
      <NuxtLink to="/login" class="font-medium text-brand underline">Inloggen</NuxtLink>
    </p>
  </AuthEduidCard>
</template>
