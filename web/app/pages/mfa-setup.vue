<script setup lang="ts">
definePageMeta({ layout: 'auth' });

const INVALID_CODE_MESSAGE =
  'This code is invalid or has expired. Use the latest code in your authenticator app and try again.';
const SETUP_ERROR_MESSAGE =
  'We could not start the setup. Go back to login and try again.';

const { signOut } = useAuth();
const { enrollTotp, verifyTotp } = useMfa();

const factorId = ref('');
const qrCode = ref('');
const secret = ref('');
const code = ref('');
const setupError = ref('');
const codeError = ref('');
const isLoading = ref(true);
const isConfirming = ref(false);

const buttonLabel = computed(() => {
  if (isConfirming.value) return 'Confirming...';
  if (codeError.value) return 'Try again';
  return 'Confirm setup';
});

async function startSetup() {
  const { data, error } = await enrollTotp();
  isLoading.value = false;
  if (error) {
    setupError.value = SETUP_ERROR_MESSAGE;
    return;
  }
  factorId.value = data.factorId;
  qrCode.value = data.qrCode;
  secret.value = data.secret;
}

async function handleSubmit() {
  isConfirming.value = true;
  const { error } = await verifyTotp(factorId.value, code.value);
  isConfirming.value = false;

  if (error) {
    codeError.value = INVALID_CODE_MESSAGE;
    return;
  }
  await navigateTo('/mfa-complete');
}

onMounted(startSetup);
</script>

<template>
  <AuthCard
    eyebrow="First-time setup"
    title="Protect your PAVE account"
    description="Two-step verification is mandatory to keep your personal information, achievements and certificates safe."
  >
    <ol class="mt-6 space-y-4">
      <AuthSetupStep
        :number="1"
        title="Get an authenticator app"
        description="Install Google Authenticator or Microsoft Authenticator on your phone."
      />
      <AuthSetupStep
        :number="2"
        title="Add your PAVE account"
        description="In the app, add an account and scan this QR code."
      >
        <div class="mt-3 flex items-center gap-4 rounded-xl bg-tint p-4">
          <p v-if="isLoading" class="text-sm text-muted">Loading QR code...</p>
          <p v-else-if="setupError" role="alert" class="text-sm text-danger">
            {{ setupError }}
          </p>
          <template v-else>
            <img
              :src="qrCode"
              alt="QR code to add PAVE to your authenticator app"
              class="size-28 shrink-0 rounded-lg bg-white p-1"
            />
            <div class="min-w-0 text-sm text-ink">
              <p class="font-semibold">Can’t scan the code?</p>
              <p class="mt-1 text-muted">Enter this key in your app instead:</p>
              <p class="mt-1 break-all font-mono">{{ secret }}</p>
            </div>
          </template>
        </div>
      </AuthSetupStep>
      <AuthSetupStep
        :number="3"
        title="Confirm the connection"
        description="Enter the 6-digit code from your authenticator app."
      />
    </ol>

    <form @submit.prevent="handleSubmit">
      <AuthCodeInput
        id="setup-code"
        v-model="code"
        hint="Enter the code shown in your authenticator app."
        :error="codeError"
      />
      <AuthPrimaryButton type="submit" :disabled="isConfirming || !factorId">
        {{ buttonLabel }}
      </AuthPrimaryButton>
    </form>

    <p class="mt-4 text-sm text-muted">
      Can’t use an authenticator app? Contact your organization’s IT support for
      help.
    </p>

    <AuthBackToLogin @click="signOut" />
  </AuthCard>
</template>
