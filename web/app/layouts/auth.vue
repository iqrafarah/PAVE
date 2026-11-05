<template>
  <div class="flex min-h-screen flex-col bg-surface">
    <header
      class="flex h-35 justify-center bg-linear-to-b from-brand-soft to-surface pt-4"
    >
      <img src="/images/logo.svg" alt="PAVE" class="h-12" />
    </header>

    <main class="mx-auto w-full max-w-card px-4">
      <slot />
    </main>

    <footer class="mt-auto px-4 pb-5 pt-20 text-center text-sm text-muted">
      <p>Need help? Contact your organization’s IT support.</p>
      <p class="mt-1 text-xs">Your progress. Your possibilities.</p>
    </footer>
  </div>
</template>
