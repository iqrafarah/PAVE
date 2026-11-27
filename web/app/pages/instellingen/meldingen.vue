<script setup lang="ts">
// Instellingen › Meldingen (iOS SettingsNotificationsScreen): whether PAVE gives a signal outside the page when a new
// notification arrives. On web that is a notification of the browser, for this browser only.
useHead({ title: `${ALERTS_SETTINGS_TITLE} - PAVE` });

const alerts = useNotificationAlerts();
const isOn = computed({
  get: () => alerts.isEnabled.value,
  set: (on: boolean) => alerts.setEnabled(on),
});
const note = computed(() => {
  if (alerts.permission.value === 'unsupported') return ALERTS_UNSUPPORTED_NOTE;
  if (alerts.permission.value === 'denied') return ALERTS_BLOCKED_NOTE;
  return ALERTS_BROWSER_NOTE;
});

onMounted(alerts.load);
</script>

<template>
  <SettingsPage :title="ALERTS_SETTINGS_TITLE">
    <SettingsSwitchCard v-model="isOn" :title="ALERTS_SWITCH" :explanation="ALERTS_SWITCH_EXPLANATION" />
    <p :role="alerts.permission.value === 'denied' ? 'alert' : undefined" class="px-3 text-xs/normal text-subtle">{{ note }}</p>
  </SettingsPage>
</template>
