<script setup lang="ts">
// How many notifications and e-mail conversations are unread, on the bell (iOS MainBellButton): "9+" above nine,
// nothing at zero.
const notifications = useNotifications();
const email = useEmail();
const count = computed(() => notifications.unreadCount.value + email.unreadCount.value);
const label = computed(() => (count.value > 9 ? '9+' : String(count.value)));
</script>

<template>
  <span
    v-if="count > 0"
    class="pointer-events-none absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand px-1 text-[0.625rem] font-bold leading-none text-white ring-[1.5px] ring-surface"
    aria-hidden="true"
  >
    {{ label }}
  </span>
</template>
