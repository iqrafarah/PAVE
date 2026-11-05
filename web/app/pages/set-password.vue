<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const RULES_NOT_MET_MESSAGE = 'Your password doesn’t meet all the requirements yet.';
const MISMATCH_MESSAGE = 'Passwords don’t match. Re-enter your new password.';
const SAME_PASSWORD_MESSAGE =
  'Choose a password that is different from your current one.';
const SAVE_ERROR_MESSAGE = 'We could not save your password. Please try again.';

const { updatePassword, signOut } = useAuth();

const password = ref('');
const confirmation = ref('');
const passwordError = ref('');
const confirmationError = ref('');
const isSaving = ref(false);

const rules = computed(() => getPasswordRules(password.value));
const isPasswordStrong = computed(() => rules.value.every((rule) => rule.isMet));

function validate() {
  passwordError.value = isPasswordStrong.value ? '' : RULES_NOT_MET_MESSAGE;
  confirmationError.value =
    password.value === confirmation.value ? '' : MISMATCH_MESSAGE;
  return !passwordError.value && !confirmationError.value;
}

function getSaveErrorMessage(errorCode?: string) {
  if (errorCode === 'same_password') return SAME_PASSWORD_MESSAGE;
  if (errorCode === 'weak_password') return RULES_NOT_MET_MESSAGE;
  return SAVE_ERROR_MESSAGE;
}

async function handleSubmit() {
  if (!validate()) return;

  isSaving.value = true;
  const { error } = await updatePassword(password.value);
  isSaving.value = false;

  if (error) {
    passwordError.value = getSaveErrorMessage(error.code);
    return;
  }
  await navigateTo('/');
}
</script>

<template>
  <AuthCard
    eyebrow="Password"
    title="Set your password"
    description="Choose a strong password that you don’t use for other accounts."
  >
    <form class="mt-8" @submit.prevent="handleSubmit">
      <AuthPasswordInput
        id="new-password"
        v-model="password"
        label="New password"
        placeholder="Enter a new password"
        autocomplete="new-password"
        :error="passwordError"
      />
      <AuthPasswordRules :rules="rules" />
      <AuthPasswordInput
        id="confirm-password"
        v-model="confirmation"
        class="mt-5"
        label="Confirm new password"
        placeholder="Re-enter your new password"
        autocomplete="new-password"
        :error="confirmationError"
      />
      <AuthPrimaryButton type="submit" :disabled="isSaving">
        {{ isSaving ? 'Saving...' : 'Save password' }}
      </AuthPrimaryButton>
    </form>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
