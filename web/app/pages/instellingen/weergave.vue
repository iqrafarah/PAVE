<script setup lang="ts">
import type { TextSize, ThemeId } from '~/utils/appearance';

useHead({ title: `${PERSONAL_TITLE} - PAVE` });
const personal = usePersonalisation();
const sync = computed(() => personal.sync.value);
const syncMessage = computed(() => {
  if (sync.value.isLoading) return PERSONAL_SYNC_LOADING;
  if (sync.value.isSaving) return PERSONAL_SYNC_SAVING;
  return sync.value.canSave ? PERSONAL_SYNCED : PERSONAL_DEVICE_NOTE;
});
const ids = { theme: useId(), view: useId(), size: useId() };
const TEXT_SIZE_ICONS: Record<TextSize, string> = { small: 'h-3 w-2.75', normal: 'h-4 w-3.5', large: 'h-5 w-4.5' };
const theme = computed({
  get: () => personal.state.value.theme,
  set: (value: ThemeId) => personal.set({ theme: value }),
});
const vaultView = computed({
  get: () => personal.state.value.isVaultGrid ? 'grid' : 'list',
  set: (value: string) => personal.set({ isVaultGrid: value === 'grid' }),
});
const textSize = computed({
  get: () => personal.state.value.textSize,
  set: (value: string) => personal.set({ textSize: value as TextSize }),
});
function setCustomColor(color: string) {
  personal.set({ theme: 'custom', customColor: color }, { save: false });
}

const heading = 'text-sm font-semibold text-heading';
const section = 'flex flex-col gap-2.5 rounded-pill bg-white p-3';
onMounted(personal.load);
</script>

<template>
  <SettingsPage :title="PERSONAL_TITLE" wide>
    <section :aria-labelledby="ids.theme" :class="section">
      <h2 :id="ids.theme" :class="heading">{{ PERSONAL_THEME }}</h2>
      <SettingsThemePicker v-model="theme" :custom-color="personal.state.value.customColor" @custom="setCustomColor" @commit="personal.saveAccount()" />
    </section>

    <section :aria-labelledby="ids.view" :class="section">
      <h2 :id="ids.view" :class="heading">{{ PERSONAL_VAULT_VIEW }}</h2>
      <div role="radiogroup" :aria-labelledby="ids.view" class="flex flex-wrap gap-2.5 [&>*]:flex-1">
        <SettingsChoice v-model="vaultView" name="pave-vault-view" value="list" :label="PERSONAL_VIEW_LIST">
          <VaultIcon src="/images/settings/list.svg" class="size-6" />
        </SettingsChoice>
        <SettingsChoice v-model="vaultView" name="pave-vault-view" value="grid" :label="PERSONAL_VIEW_GRID">
          <VaultIcon src="/images/settings/grid.svg" class="size-6" />
        </SettingsChoice>
      </div>
      <p class="text-xs/normal text-subtle">{{ PERSONAL_VAULT_HINT }}</p>
    </section>

    <section :aria-labelledby="ids.size" :class="section">
      <h2 :id="ids.size" :class="heading">{{ PERSONAL_TEXT_SIZE }}</h2>
      <div role="radiogroup" :aria-labelledby="ids.size" class="flex flex-wrap gap-2.5 [&>*]:flex-1">
        <SettingsChoice
          v-for="option in PERSONAL_TEXT_SIZES"
          :key="option.id"
          v-model="textSize"
          name="pave-text-size"
          :value="option.id"
          :label="option.name"
        >
          <span class="flex w-4.5 justify-center"><LayoutAylaGlyph :class="TEXT_SIZE_ICONS[option.id]" /></span>
        </SettingsChoice>
      </div>
    </section>
    <p v-if="!sync.problem" role="status" class="px-2 text-xs/normal text-subtle">{{ syncMessage }}</p>
    <div v-if="sync.problem" class="flex flex-col gap-2 px-2">
      <p role="alert" class="text-sm text-danger">{{ sync.problem }}</p>
      <button type="button" :disabled="sync.isLoading || sync.isSaving" class="min-h-11 self-start rounded-lg px-3 text-sm font-semibold text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60" @click="personal.saveAccount()">{{ DEVICES_RETRY }}</button>
    </div>
    <p v-if="personal.storageProblem.value" role="status" class="px-2 text-xs/normal text-subtle">{{ personal.storageProblem.value }}</p>
  </SettingsPage>
</template>
