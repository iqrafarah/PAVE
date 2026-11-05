<script setup lang="ts">
const { user, signOut } = useAuth();
</script>

<template>
  <main>
    <h1>Welkom bij PAVE</h1>
    <p>Ingelogd als {{ user?.email }}</p>
    <button type="button" @click="signOut">Uitloggen</button>
  </main>
</template>
