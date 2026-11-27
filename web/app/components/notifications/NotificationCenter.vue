<script setup lang="ts">
// Meldingen outside the Meldingen page (iOS MainView): keeps the inbox fresh while signed in, so the bell has its count,
// and the connected mailbox too (useEmail), and shows the banner for a notification that arrives while PAVE is open. On Meldingen itself the list shows it.
const route = useRoute();
const user = useSupabaseUser();
const notifications = useNotifications();
const email = useEmail();
const alerts = useNotificationAlerts();

const banner = computed(() => (route.path === '/meldingen' ? null : notifications.state.value.banner));

function open() {
  const shown = banner.value;
  notifications.dismissBanner();
  if (shown) navigateTo({ path: '/meldingen', query: { melding: shown.id } });
}

onMounted(() => {
  alerts.load();
  watch(
    () => user.value?.sub,
    (id, previousId) => {
      if (previousId && id !== previousId) {
        notifications.stop();
        email.stop();
      }
      if (id) {
        notifications.start();
        email.start();
      }
    },
    { immediate: true },
  );
});

onBeforeUnmount(() => {
  notifications.stop();
  email.stop();
});
</script>

<template>
  <NotificationBanner v-if="banner" :notification="banner" @open="open" @dismiss="notifications.dismissBanner()" />
</template>
