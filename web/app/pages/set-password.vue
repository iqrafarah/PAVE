<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const { updatePassword, signOut } = useAuth();

const password = ref('');
const confirmation = ref('');
const passwordError = ref('');
const confirmationError = ref('');
const isSaving = ref(false);

const rules = computed(() => getPasswordRules(password.value));
const isPasswordStrong = computed(() => rules.value.every((rule) => rule.isMet));

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
  await navigateTo(HOME_PATH);
}
</script>

<template>
  <AuthCard
    eyebrow="Wachtwoord"
    title="Kies een nieuw wachtwoord"
    description="Kies een sterk wachtwoord dat je nergens anders gebruikt."
  >
    <form class="mt-8" @submit.prevent="handleSubmit">
      <AuthPasswordInput
        id="new-password"
        v-model="password"
        label="Nieuw wachtwoord"
        placeholder="Vul een nieuw wachtwoord in"
        autocomplete="new-password"
        :error="passwordError"
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
      />
      <AuthPrimaryButton type="submit" :disabled="isSaving">
        {{ isSaving ? 'Bezig met opslaan...' : 'Wachtwoord opslaan' }}
      </AuthPrimaryButton>
    </form>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
