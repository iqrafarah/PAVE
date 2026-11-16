<script setup lang="ts">
defineProps<{
  id: string;
}>();

const email = defineModel<string>({ required: true });
</script>

<template>
  <div>
    <label :for="id" class="block text-sm font-medium text-ink">E-mailadres</label>
    <input
      :id="id"
      v-model="email"
      type="email"
      required
      autocomplete="email"
      placeholder="E-mailadres"
      class="mt-2 h-13 w-full rounded-lg border border-line px-3.5 text-base text-ink placeholder:text-muted focus-visible:outline-2 focus-visible:outline-brand"
    />
  </div>
</template>
