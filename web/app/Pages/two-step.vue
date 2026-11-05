<script setup lang="ts">
const CODE_LENGTH = 6;

const { signOut } = useAuth();
const { getVerifiedFactorId, enrollAuthenticator, verifyCode } =
  useTwoStepVerification();

const factorId = ref<string | null>(null);
const qrCode = ref('');
const secret = ref('');
const code = ref('');
const errorMessage = ref('');
const isLoading = ref(true);
const isVerifying = ref(false);

const isEnrolling = computed(() => qrCode.value !== '');
const heading = computed(() =>
  isEnrolling.value
    ? 'Set up two-step verification'
    : 'Enter your verification code',
);

async function loadFactor() {
  const { factorId: verifiedFactorId, error } = await getVerifiedFactorId();
  if (error) {
    errorMessage.value =
      'Could not load two-step verification. Please try again.';
    return;
  }
  if (verifiedFactorId) {
    factorId.value = verifiedFactorId;
    return;
  }
  await startEnrollment();
}

async function startEnrollment() {
  const { data, error } = await enrollAuthenticator();
  if (error) {
    errorMessage.value = 'Could not start two-step setup. Please try again.';
    return;
  }
  factorId.value = data.factorId;
  qrCode.value = data.qrCode;
  secret.value = data.secret;
}

async function handleSubmit() {
  if (!factorId.value) return;
  errorMessage.value = '';
  isVerifying.value = true;

  const { error } = await verifyCode(factorId.value, code.value);

  isVerifying.value = false;
  if (error) {
    errorMessage.value =
      'That code is not valid. Check your authenticator app and try again.';
    code.value = '';
    return;
  }
  await navigateTo('/');
}

onMounted(async () => {
  await loadFactor();
  isLoading.value = false;
});
</script>

<template>
  <div class="flex min-h-screen flex-col bg-surface">
    <header
      class="flex h-35 justify-center bg-linear-to-b from-brand-soft to-surface pt-4"
    >
      <img src="/images/logo.svg" alt="PAVE" class="h-12" />
    </header>

    <main class="mx-auto w-full max-w-card px-4">
      <section class="rounded-2xl border border-line bg-white p-10">
        <p class="text-sm font-medium text-brand">Two-step verification</p>
        <h1 class="mt-3 text-3xl font-semibold text-ink">{{ heading }}</h1>

        <p v-if="isLoading" class="mt-3 text-base text-muted">Loading...</p>

        <template v-else>
          <div v-if="isEnrolling" class="mt-3">
            <p class="text-base text-muted">
              Scan this QR code with an authenticator app, such as Google
              Authenticator or Microsoft Authenticator.
            </p>
            <img
              :src="qrCode"
              alt="QR code for your authenticator app"
              class="mx-auto mt-6 size-48"
            />
            <p class="mt-4 text-sm text-muted">
              Can’t scan it? Enter this key instead:
            </p>
            <p
              class="mt-1 break-all rounded-lg bg-tint p-3 font-mono text-sm text-ink"
            >
              {{ secret }}
            </p>
          </div>
          <p v-else class="mt-3 text-base text-muted">
            Open your authenticator app and enter the {{ CODE_LENGTH }}-digit
            code for PAVE.
          </p>

          <form v-if="factorId" class="mt-8" @submit.prevent="handleSubmit">
            <label for="code" class="block text-sm font-medium text-ink"
              >Verification code</label
            >
            <input
              id="code"
              v-model="code"
              type="text"
              required
              inputmode="numeric"
              autocomplete="one-time-code"
              :maxlength="CODE_LENGTH"
              :pattern="`[0-9]{${CODE_LENGTH}}`"
              placeholder="123456"
              class="mt-2 h-13 w-full rounded-lg border border-line px-3.5 text-base tracking-widest text-ink placeholder:text-muted focus-visible:outline-2 focus-visible:outline-brand"
            />

            <button
              type="submit"
              :disabled="isVerifying"
              class="mt-6 h-13 w-full rounded-lg bg-brand text-base font-semibold text-white hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
            >
              {{ isVerifying ? 'Verifying...' : 'Verify' }}
            </button>
          </form>

          <p v-if="errorMessage" role="alert" class="mt-4 text-sm text-danger">
            {{ errorMessage }}
          </p>
        </template>

        <button
          type="button"
          class="mt-6 text-sm font-medium text-brand focus-visible:outline-2 focus-visible:outline-brand"
          @click="signOut"
        >
          Sign in with a different account
        </button>
      </section>
    </main>

    <footer class="mt-auto px-4 pb-5 pt-20 text-center text-sm text-muted">
      <p>
        Lost access to your authenticator app? Contact your organization’s IT
        support.
      </p>
    </footer>
  </div>
</template>
