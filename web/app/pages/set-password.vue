<script setup lang="ts">
import type { MfaStatus } from '~/utils/mfaRoutes';
import type { PasswordFieldState } from '~/utils/passwordRules';

definePageMeta({ layout: 'auth' });

const { isPasswordReset, updatePassword, finishPasswordReset, signOut } =
  useAuth();
const { getMfaStatus } = useMfa();

const password = ref('');
const confirmation = ref('');
const passwordError = ref('');
const confirmationError = ref('');
const isSaving = ref(false);
const hasLeftConfirmation = ref(false);
const resetSteps = ref<string[]>([]);

const rules = computed(() => getPasswordRules(password.value));
const isPasswordStrong = computed(() => rules.value.every((rule) => rule.isMet));
const doPasswordsMatch = computed(() => password.value === confirmation.value);
const canSubmit = computed(() => isPasswordStrong.value && doPasswordsMatch.value);
const passwordState = computed<PasswordFieldState>(() =>
  isPasswordStrong.value ? 'valid' : 'incomplete',
);
const confirmationState = computed<PasswordFieldState>(() =>
  doPasswordsMatch.value ? 'valid' : 'incomplete',
);
const confirmationStatus = computed(() => {
  if (doPasswordsMatch.value) return PASSWORDS_MATCH_MESSAGE;
  const areBothFilled = Boolean(password.value && confirmation.value);
  if (hasLeftConfirmation.value && areBothFilled) return PASSWORDS_NOT_EQUAL_MESSAGE;
  return '';
});
const currentStepIndex = computed(() => resetSteps.value.length - 1);

function validate() {
  passwordError.value = isPasswordStrong.value
    ? ''
    : PASSWORD_RULES_NOT_MET_MESSAGE;
  confirmationError.value =
    password.value === confirmation.value ? '' : PASSWORDS_DIFFER_MESSAGE;
  return !passwordError.value && !confirmationError.value;
}

async function handleSubmit() {
  if (!validate()) return;

  isSaving.value = true;
  const { error } = await updatePassword(password.value);
  isSaving.value = false;

  if (error) {
    passwordError.value = getAuthErrorMessage(error);
    return;
  }
  await goToNextStep();
}

async function goToNextStep() {
  if (!isPasswordReset.value) {
    await navigateTo(HOME_PATH);
    return;
  }
  // The password is already saved. If signing out fails here, the button on the next page signs out again.
  await finishPasswordReset();
  await navigateTo(PASSWORD_UPDATED_PATH);
}

function clearErrors() {
  passwordError.value = '';
  confirmationError.value = '';
}

function getResetSteps(status: MfaStatus | null) {
  if (status === 'complete') return RESET_STEPS;
  if (status === 'needs-setup') return RESET_STEPS_WITHOUT_AUTHENTICATOR;
  return [];
}

async function loadResetSteps() {
  if (!isPasswordReset.value) return;

  const { data: status } = await getMfaStatus();
  resetSteps.value = getResetSteps(status);
}

watch([password, confirmation], clearErrors);
onMounted(loadResetSteps);
</script>

<template>
  <AuthCard
    eyebrow="Wachtwoord"
    title="Kies een nieuw wachtwoord"
    :description="NEW_PASSWORD_INSTRUCTION"
  >
    <template v-if="resetSteps.length > 0" #steps>
      <AuthSteps :steps="resetSteps" :current-index="currentStepIndex" />
    </template>

    <form @submit.prevent="handleSubmit">
      <AuthPasswordInput
        id="new-password"
        v-model="password"
        label="Nieuw wachtwoord"
        placeholder="Vul een nieuw wachtwoord in"
        autocomplete="new-password"
        :error="passwordError"
        :state="passwordState"
        is-copy-blocked
      />
      <AuthPasswordRules :rules="rules" />
      <AuthPasswordInput
        id="confirm-password"
        v-model="confirmation"
        class="mt-5"
        label="Herhaal je nieuwe wachtwoord"
        placeholder="Vul je nieuwe wachtwoord nog een keer in"
        autocomplete="new-password"
        :error="confirmationError"
        :state="confirmationState"
        :status="confirmationStatus"
        :hint="REPEAT_PASSWORD_HINT"
        is-copy-blocked
        is-paste-blocked
        @blur="hasLeftConfirmation = true"
      />
      <AuthPrimaryButton type="submit" :disabled="isSaving || !canSubmit">
        {{ isSaving ? 'Bezig met opslaan...' : 'Wachtwoord opslaan' }}
      </AuthPrimaryButton>
    </form>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
