<script setup lang="ts">
// Shown in place of a page that broke while it was drawn (NuxtErrorBoundary in the layout). The menu around it keeps
// working, "Opnieuw proberen" draws the page again, and going to another page clears it by itself.
const props = defineProps<{
  error: unknown;
}>();

const emit = defineEmits<{
  retry: [];
}>();

const route = useRoute();

watch(
  () => route.path,
  () => emit('retry'),
);

onMounted(() => {
  if (import.meta.dev) console.error('A page could not be shown', props.error);
});
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col items-center justify-center gap-5 overflow-y-auto bg-surface px-8 py-10" role="alert">
    <LayoutEmptyState icon="folder" :title="ERROR_PAGE_TITLE" :message="ERROR_PAGE_MESSAGE" />
    <div class="flex flex-wrap justify-center gap-2.5">
      <button
        type="button"
        class="min-h-10 rounded-lg bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="emit('retry')"
      >
        {{ ERROR_RETRY }}
      </button>
      <NuxtLink
        to="/"
        class="flex min-h-10 items-center rounded-lg bg-tint px-4 text-sm font-medium text-brand hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      >
        {{ ERROR_HOME }}
      </NuxtLink>
    </div>
  </div>
</template>
