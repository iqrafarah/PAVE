<script setup lang="ts">
const supabase = useSupabaseClient();
const status = ref('Checking Supabase connection...');

onMounted(async () => {
  const { error } = await supabase.auth.getSession();

  status.value = error
    ? `Connection failed: ${error.message}`
    : 'Supabase connection is working.';
});
</script>

<template>
  <main>
    <h1>Supabase connection test</h1>
    <p>{{ status }}</p>
  </main>
</template>
