<script setup lang="ts">
useHead({ title: `${SETTINGS_PRIVACY} - PAVE` });
</script>

<template>
  <SettingsPage :title="SETTINGS_PRIVACY">
    <SettingsLinkCard :to="MEMORY_PAGE_PATH" :title="SETTINGS_MEMORY_LINK" message="Bekijk, pas aan of wis wat Ayla onthoudt." />
    <SettingsLinkCard :to="DEVICES_PATH" :title="DEVICES_TITLE" message="Bekijk waar je bent ingelogd en log andere apparaten uit." />
    <div class="flex flex-col gap-2 rounded-pill bg-white p-3">
      <h2 class="text-base font-semibold text-heading">Op je iPhone</h2>
      <p class="text-xs/normal text-subtle">{{ SETTINGS_PRIVACY_DEVICE_NOTE }}</p>
    </div>
  </SettingsPage>
</template>
