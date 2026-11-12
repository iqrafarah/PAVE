<script setup lang="ts">
import type { TextSize, ThemeId } from '~/composables/usePersonalisation';

useHead({ title: `${PERSONAL_TITLE} - PAVE` });
const personal = usePersonalisation();
const ids = { theme: useId(), view: useId(), size: useId() };
const TEXT_SIZE_ICONS: Record<TextSize, string> = { small: 'h-3 w-2.75', normal: 'h-4 w-3.5', large: 'h-5 w-4.5' };
const theme = computed({
  get: () => personal.state.value.theme,
  set: (value: string) => personal.set({ theme: value as ThemeId }),
});
const vaultView = computed({
  get: () => personal.state.value.isVaultGrid ? 'grid' : 'list',
  set: (value: string) => personal.set({ isVaultGrid: value === 'grid' }),
});
const textSize = computed({
  get: () => personal.state.value.textSize,
  set: (value: string) => personal.set({ textSize: value as TextSize }),
});
const heading = 'text-sm font-semibold text-heading';
const section = 'flex flex-col gap-2.5 rounded-pill bg-white p-3';
onMounted(personal.load);
</script>

<template>
  <SettingsPage :title="PERSONAL_TITLE">
      <section :aria-labelledby="ids.theme" :class="section">
        <h2 :id="ids.theme" :class="heading">{{ PERSONAL_THEME }}</h2>
        <div role="radiogroup" :aria-labelledby="ids.theme" class="grid grid-cols-[repeat(auto-fit,3.25rem)] gap-2.5">
          <label
            v-for="option in PERSONAL_THEMES"
            :key="option.id"
            :title="option.name"
            :style="{ '--swatch': option.hex }"
            :class="theme === option.id ? 'border-(--swatch) p-1.25' : 'border-transparent p-0'"
            class="flex size-13 cursor-pointer rounded-full border transition-[padding] has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand motion-reduce:transition-none"
          >
            <input v-model="theme" type="radio" name="pave-theme" :value="option.id" class="sr-only" />
            <span class="flex-1 rounded-full bg-(--swatch)" aria-hidden="true" />
            <span class="sr-only">{{ option.name }}</span>
          </label>
        </div>
      </section>

      <section :aria-labelledby="ids.view" :class="section">
        <h2 :id="ids.view" :class="heading">{{ PERSONAL_VAULT_VIEW }}</h2>
        <div role="radiogroup" :aria-labelledby="ids.view" class="grid gap-2.5 sm:grid-cols-2">
          <SettingsChoice v-model="vaultView" name="pave-vault-view" value="list" :label="PERSONAL_VIEW_LIST">
            <VaultIcon src="/images/settings/list.svg" class="h-4.5 w-6" />
          </SettingsChoice>
          <SettingsChoice v-model="vaultView" name="pave-vault-view" value="grid" :label="PERSONAL_VIEW_GRID">
            <VaultIcon src="/images/settings/grid.svg" class="size-8.5" />
          </SettingsChoice>
        </div>
        <p class="text-xs/normal text-subtle">{{ PERSONAL_VAULT_HINT }}</p>
      </section>

      <section :aria-labelledby="ids.size" :class="section">
        <h2 :id="ids.size" :class="heading">{{ PERSONAL_TEXT_SIZE }}</h2>
        <div role="radiogroup" :aria-labelledby="ids.size" class="grid gap-2.5 sm:grid-cols-3">
          <SettingsChoice
            v-for="option in PERSONAL_TEXT_SIZES"
            :key="option.id"
            v-model="textSize"
            name="pave-text-size"
            :value="option.id"
            :label="option.name"
            is-small
          >
            <span class="flex w-4.5 justify-center"><LayoutAylaGlyph :class="TEXT_SIZE_ICONS[option.id]" /></span>
          </SettingsChoice>
        </div>

      </section>
    <p class="px-2 text-xs/normal text-subtle">{{ PERSONAL_DEVICE_NOTE }}</p>
  </SettingsPage>
</template>
