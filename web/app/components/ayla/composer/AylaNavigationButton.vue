<script setup lang="ts">
import type { AylaScreen } from '~/types/ayla';

const props = defineProps<{
  screen: AylaScreen;
}>();

const router = useRouter();

// Only screens that exist on the web get a button; nothing opens by itself.
const screenRoute = computed(() => {
  const found = getScreenRoute(props.screen);
  if (!found || !hasPageAt(router.getRoutes(), found.path)) return null;
  return found;
});
</script>

<template>
  <NuxtLink
    v-if="screenRoute"
    :to="screenRoute.path"
    class="mt-3 inline-flex min-h-10 items-center gap-2 rounded-full border border-brand px-4 text-sm font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
  >
    {{ getOpenScreenLabel(screenRoute.name) }}
  </NuxtLink>
</template>
