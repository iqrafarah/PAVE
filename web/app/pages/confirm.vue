<script setup lang="ts">
const { user } = useAuth();

watch(
  user,
  () => {
    if (user.value) navigateTo('/');
  },
  { immediate: true },
);
</script>

<template>
  <main>
    <p>Verifying your email...</p>
  </main>
</template>
