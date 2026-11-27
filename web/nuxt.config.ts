import tailwindcss from '@tailwindcss/vite';

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: false },
  modules: ['@nuxtjs/supabase'],
  // Feature subfolders organize files without changing component names in templates.
  components: [{ path: '~/components', pathPrefix: false }],
  imports: {
    dirs: ['~/composables/**', '~/utils/**'],
  },
  app: {
    head: {
      htmlAttrs: { lang: 'nl' },
      link: [
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        {
          rel: 'preconnect',
          href: 'https://fonts.gstatic.com',
          crossorigin: '',
        },
        {
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Public+Sans:wght@600&family=Sora:wght@600&display=swap',
        },
      ],
    },
  },
  // Server only: the key that encrypts the app-specific passwords of connected mailboxes (NUXT_EMAIL_SECRET, at least
  // 32 characters, e.g. `openssl rand -base64 48`). Without it e-mail in Meldingen says it is not available.
  runtimeConfig: {
    emailSecret: '',
  },
  css: ['~/assets/css/main.css'],
  vite: {
    plugins: [tailwindcss()],
  },
  supabase: {
    redirectOptions: {
      login: '/login',
      callback: '/confirm',
      // A shared profile, an employer at a fair and the fair itself open without an account.
      exclude: ['/register', '/forgot-password', '/password-updated', '/gedeeld/*', '/werkgever/*', '/inbox/*', '/beurs'],
    },
  },
});
