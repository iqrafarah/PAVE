<script setup lang="ts">
import type { NuxtError } from '#app';

// The page for an error the app could not recover from by itself (a link that does not exist, or a failure while the
// site starts): a calm message and a way on, instead of a blank screen or a technical report.
const props = defineProps<{
  error: NuxtError;
}>();

const isNotFound = computed(() => props.error?.statusCode === 404);
const title = computed(() => (isNotFound.value ? ERROR_NOT_FOUND_TITLE : ERROR_PAGE_TITLE));

useHead({ title: () => `${title.value} - PAVE` });

onMounted(() => {
  if (import.meta.dev) console.error(props.error);
});

/** Clears the error and loads the page again from the server, so a broken start gets a clean one. */
function retry() {
  clearError();
  window.location.reload();
}
</script>

<template>
  <main class="flex min-h-dvh flex-col items-center justify-center gap-6 bg-surface px-6 py-10 text-center text-ink">
    <LayoutPaveLogo full class="h-12 w-27.5" />
    <div class="flex max-w-90 flex-col gap-2">
      <h1 class="font-heading text-2xl font-semibold text-heading">{{ title }}</h1>
      <p class="text-sm font-medium text-subtle">{{ isNotFound ? ERROR_NOT_FOUND_MESSAGE : ERROR_PAGE_MESSAGE }}</p>
    </div>
    <div class="flex flex-wrap justify-center gap-2.5">
      <button
        v-if="!isNotFound"
        type="button"
        class="min-h-10 rounded-lg bg-brand px-4 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="retry"
      >
        {{ ERROR_RETRY }}
      </button>
      <button
        type="button"
        :class="isNotFound ? 'bg-brand text-white hover:bg-ink' : 'bg-tint text-brand hover:bg-brand-soft'"
        class="min-h-10 rounded-lg px-4 text-sm font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="clearError({ redirect: '/' })"
      >
        {{ ERROR_HOME }}
      </button>
    </div>
  </main>
</template>
