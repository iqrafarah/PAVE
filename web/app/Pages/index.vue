<script setup lang="ts">
const { user, signOut } = useAuth();
</script>

<template>
  <main>
    <h1>Welcome to PAVE</h1>
    <p>Logged in as {{ user?.email }}</p>
    <button type="button" @click="signOut">Log out</button>
  </main>
</template>
