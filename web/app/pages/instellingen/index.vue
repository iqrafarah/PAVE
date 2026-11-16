<script setup lang="ts">
useHead({ title: `${SETTINGS_TITLE} - PAVE` });

const account = useAccount();
const personal = usePersonalisation();
const memory = useAylaMemory();
const generalHeadingId = useId();
const aylaHeadingId = useId();
const themeName = computed(() => personal.state.value.theme === 'custom'
  ? PERSONAL_CUSTOM_COLOR
  : PERSONAL_THEMES.find((theme) => theme.id === personal.state.value.theme)?.name);
const memorySummary = computed(() => {
  const summary = getMemorySummary(memory.state.value.status, memory.state.value.isEnabled, memory.state.value.notes.length);
  return summary.length <= 22 ? summary : undefined;
});

onMounted(() => {
  personal.load();
  account.load();
  if (memory.state.value.status === 'idle') memory.load();
});
</script>

<template>
  <div class="min-h-0 flex-1 overflow-y-auto bg-surface">
    <SettingsPageHeader :title="SETTINGS_TITLE" />
    <div class="mx-auto flex w-full max-w-140 flex-col gap-3 px-5.75 pb-8 pt-8">
      <NuxtLink :to="SETTINGS_ACCOUNT_PATH" class="flex items-center gap-3.5 rounded-pill bg-white p-3.5 hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand">
        <SettingsAccountBadge :name="account.state.value.fullName" :avatar-url="account.state.value.avatarUrl" size="large" />
        <span class="flex min-w-0 flex-1 flex-col gap-0.75">
          <span class="truncate font-heading text-xl font-semibold text-heading">{{ account.state.value.fullName ?? SETTINGS_YOUR_ACCOUNT }}</span>
          <span class="truncate text-xs text-subtle">{{ account.state.value.email ?? SETTINGS_ACCOUNT_SUBTITLE }}</span>
        </span>
        <LayoutPaveIcon name="chevronRight" class="size-3.5 text-subtle" />
      </NuxtLink>

      <section :aria-labelledby="generalHeadingId" class="flex flex-col gap-3 pt-2">
        <SettingsSectionTitle :id="generalHeadingId" :title="SETTINGS_GENERAL" />
        <SettingsGroup>
          <SettingsRow :to="SETTINGS_APPEARANCE_PATH" :title="PERSONAL_TITLE" icon="/images/settings/appearance.svg" :value="themeName" />
          <SettingsRow :to="DEVICES_PATH" :title="DEVICES_TITLE" icon="/images/settings/phone.svg" />
        </SettingsGroup>
      </section>
      <section :aria-labelledby="aylaHeadingId" class="flex flex-col gap-3 pt-2">
        <SettingsSectionTitle :id="aylaHeadingId" :title="SETTINGS_AYLA_PRIVACY" />
        <SettingsGroup>
          <SettingsRow :to="SETTINGS_AYLA_PATH" :title="SETTINGS_AYLA" icon="/images/settings/chat.svg" :value="memorySummary" />
          <SettingsRow :to="SETTINGS_PRIVACY_PATH" :title="SETTINGS_PRIVACY" icon="/images/settings/privacy.svg" />
        </SettingsGroup>
      </section>
    </div>
  </div>
</template>
