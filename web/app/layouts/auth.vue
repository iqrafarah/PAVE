<template>
  <div class="flex min-h-screen flex-col bg-surface">
    <header
      class="flex h-28 justify-center bg-linear-to-b from-brand-soft to-surface pt-4"
    >
      <LayoutPaveLogo full class="h-12 w-27.5" />
    </header>

    <main class="mx-auto my-auto w-full max-w-card px-4 py-6">
      <slot />
    </main>

    <footer class="px-4 pb-5 pt-8 text-center text-sm text-muted">
      <p>Hulp nodig? Neem contact op via <AuthSupportLink />.</p>
      <p class="mt-1 text-xs">Jouw voortgang. Jouw mogelijkheden.</p>
    </footer>
  </div>
</template>
