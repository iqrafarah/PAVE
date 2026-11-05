<script setup lang="ts">
import type { PasswordRule } from '~/utils/passwordRules';

defineProps<{
  rules: PasswordRule[];
}>();
</script>

<template>
  <div class="mt-4 rounded-xl bg-tint p-4 text-sm text-ink">
    <p class="font-semibold">Eisen voor je wachtwoord:</p>
    <ul class="mt-2 space-y-1">
      <li v-for="rule in rules" :key="rule.label" class="flex items-center gap-2">
        <svg
          v-if="rule.isMet"
          class="size-4 shrink-0 text-brand"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="2"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
        </svg>
        <svg
          v-else
          class="size-4 shrink-0 text-muted"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="8" />
        </svg>
        <span>{{ rule.label }}</span>
        <span class="sr-only">{{ rule.isMet ? '(in orde)' : '(nog niet in orde)' }}</span>
      </li>
    </ul>
  </div>
</template>
