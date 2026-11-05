<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const SETUP_START_FAILED_MESSAGE =
  'Het instellen kon niet starten. Ga terug naar inloggen en log opnieuw in.';

const { signOut } = useAuth();
const { startSetup, confirmSetup } = useMfa();

const factorId = ref('');
const qrCode = ref('');
const secret = ref('');
const code = ref('');
const setupError = ref('');
const codeError = ref('');
const isLoading = ref(true);
const isConfirming = ref(false);

const buttonLabel = computed(() => {
  if (isConfirming.value) return 'Bezig met bevestigen...';
  if (codeError.value) return 'Opnieuw proberen';
  return 'Instellen bevestigen';
});

async function loadSetup() {
  const { data, error } = await startSetup();
  isLoading.value = false;
  if (error) {
    setupError.value = SETUP_START_FAILED_MESSAGE;
    return;
  }
  factorId.value = data.factorId;
  qrCode.value = data.qrCode;
  secret.value = data.secret;
}

async function handleSubmit() {
  codeError.value = '';
  isConfirming.value = true;
  const { error } = await confirmSetup(factorId.value, code.value);
  isConfirming.value = false;

  if (error) {
    codeError.value = getAuthErrorMessage(error);
    code.value = '';
    return;
  }
  await navigateTo(MFA_COMPLETE_PATH);
}

onMounted(loadSetup);
</script>

<template>
  <AuthCard
    eyebrow="Eerste keer instellen"
    title="Beveilig je PAVE-account"
    description="Tweestapsverificatie is verplicht. Zo blijven je persoonlijke gegevens, resultaten en certificaten veilig."
  >
    <ol class="mt-6 space-y-4">
      <AuthSetupStep
        :number="1"
        title="Download een authenticator-app"
        description="Installeer bijvoorbeeld Google Authenticator of Microsoft Authenticator op je telefoon."
      />
      <AuthSetupStep
        :number="2"
        title="Voeg je PAVE-account toe"
        description="Open je authenticator-app, voeg een account toe en scan deze code."
      >
        <div class="mt-3 flex items-center gap-4 rounded-xl bg-tint p-4">
          <p v-if="isLoading" role="status" class="text-sm text-muted">
            QR-code laden...
          </p>
          <p v-else-if="setupError" role="alert" class="text-sm text-danger">
            {{ setupError }}
          </p>
          <template v-else>
            <img
              :src="qrCode"
              alt="QR-code voor je authenticator-app"
              class="size-28 shrink-0 rounded-lg bg-white p-1"
            />
            <div class="min-w-0 text-sm text-ink">
              <p class="font-semibold">Lukt scannen niet?</p>
              <p class="mt-1 text-muted">Vul dan deze instelsleutel in:</p>
              <p class="mt-1 break-all font-mono">{{ secret }}</p>
            </div>
          </template>
        </div>
      </AuthSetupStep>
      <AuthSetupStep
        :number="3"
        title="Vul de code in"
        description="Vul hieronder de code van 6 cijfers uit je authenticator-app in."
      />
    </ol>

    <form @submit.prevent="handleSubmit">
      <AuthCodeInput
        id="setup-code"
        v-model="code"
        hint="Vul de code in die je authenticator-app nu laat zien."
        :error="codeError"
      />
      <AuthPrimaryButton type="submit" :disabled="isConfirming || !factorId">
        {{ buttonLabel }}
      </AuthPrimaryButton>
    </form>

    <p class="mt-4 text-sm text-muted">
      Lukt het instellen niet? Neem contact op via <AuthSupportLink />.
    </p>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
