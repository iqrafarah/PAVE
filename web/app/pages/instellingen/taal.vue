<script setup lang="ts">
import type { PaveLanguage } from '~/utils/settings/language';
import { PAVE_LANGUAGES } from '~/utils/settings/language';

// Instellingen › Taal (iOS SettingsLanguageScreen): Nederlands, English or Papiamentu. Each language is shown in its own
// name and PAVE changes at once, so you never get stuck in a language you cannot read.
useHead({ title: `${LANGUAGE_TITLE} - PAVE` });

const language = useLanguage();
const chosen = computed({
  get: () => language.state.value.language as string,
  set: (value: string) => language.select(value as PaveLanguage),
});
const id = useId();
</script>

<template>
  <SettingsPage :title="LANGUAGE_TITLE">
    <div role="radiogroup" :aria-labelledby="id" class="flex flex-col gap-2.5">
      <span :id="id" class="sr-only">{{ LANGUAGE_TITLE }}</span>
      <SettingsChoice
        v-for="option in PAVE_LANGUAGES"
        :key="option.id"
        v-model="chosen"
        name="pave-language"
        :value="option.id"
        :label="option.nativeName"
        :lang="option.id"
        translate="no"
      >
        <span class="text-xl leading-none">{{ option.flag }}</span>
      </SettingsChoice>
    </div>
    <p class="px-3 text-xs/normal text-subtle">
      {{ LANGUAGE_HINT }} {{ language.state.value.savesToAccount ? LANGUAGE_SYNCED : LANGUAGE_LOCAL }}
    </p>
    <p v-if="language.problem.value" role="alert" class="px-3 text-sm text-danger">{{ language.problem.value }}</p>
  </SettingsPage>
</template>
