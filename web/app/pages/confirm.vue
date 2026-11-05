<script setup lang="ts">
import type { EmailLinkType } from '~/composables/useAuth';

definePageMeta({ layout: 'auth' });

const NEXT_PATH_BY_TYPE: Record<EmailLinkType, string> = {
  invite: '/set-password',
  email: '/',
};
const INVALID_LINK_MESSAGE =
  'This link is invalid or has expired. Request a new link or contact IT support.';

const route = useRoute();
const { verifyEmailLink } = useAuth();

const errorMessage = ref('');

function isEmailLinkType(value: unknown): value is EmailLinkType {
  return typeof value === 'string' && value in NEXT_PATH_BY_TYPE;
}

async function verifyLink() {
  const tokenHash = route.query.token_hash;
  const type = route.query.type;
  if (typeof tokenHash !== 'string' || !isEmailLinkType(type)) {
    errorMessage.value = INVALID_LINK_MESSAGE;
    return;
  }

  const { error } = await verifyEmailLink(tokenHash, type);
  if (error) {
    errorMessage.value = INVALID_LINK_MESSAGE;
    return;
  }
  await navigateTo(NEXT_PATH_BY_TYPE[type], { replace: true });
}

onMounted(verifyLink);
</script>

<template>
  <AuthCard
    eyebrow="Email link"
    title="Checking your link"
    description="This only takes a moment."
  >
    <p v-if="errorMessage" role="alert" class="mt-6 text-sm text-danger">
      {{ errorMessage }}
    </p>
    <p v-else role="status" class="mt-6 text-sm text-muted">Verifying...</p>

    <AuthBackToLogin @click="navigateTo('/login')" />
  </AuthCard>
</template>
