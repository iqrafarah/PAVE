<template>
  <!-- For people without PAVE: a shared profile, an employer at a fair. Only the logo, no menu. -->
  <div class="flex min-h-screen flex-col bg-surface">
    <header class="flex h-24 justify-center bg-linear-to-b from-brand-soft to-surface pt-4">
      <LayoutPaveLogo full class="h-11 w-25" />
    </header>
    <main class="mx-auto w-full max-w-2xl px-4 py-6">
      <slot />
    </main>
    <footer class="px-4 pb-6 pt-8 text-center text-xs text-muted">
      <p>PAVE is een prototype van een Fontys-studententeam voor Npuls en SURF, met voorbeeldgegevens.</p>
    </footer>
  </div>
</template>
