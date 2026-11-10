<script setup lang="ts">
import type { PasswordRule } from '~/utils/passwordRules';

const props = defineProps<{
  rules: PasswordRule[];
}>();

const remainingCount = computed(() => props.rules.filter((rule) => !rule.isMet).length);
const progressMessage = computed(() => getRemainingRulesMessage(remainingCount.value));
</script>

<template>
  <div class="mt-4 rounded-xl bg-tint p-4 text-sm text-ink">
    <p class="font-semibold">Eisen voor je wachtwoord:</p>
    <ul class="mt-2 space-y-1">
      <li v-for="rule in rules" :key="rule.label" class="flex items-center gap-2">
        <AuthCheckIcon :is-checked="rule.isMet" />
        <span>{{ rule.label }}</span>
        <span class="sr-only">{{ rule.isMet ? '(in orde)' : '(nog niet in orde)' }}</span>
      </li>
    </ul>
    <p aria-live="polite" class="mt-3 font-medium">{{ progressMessage }}</p>
  </div>
</template>
