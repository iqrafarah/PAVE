import tailwindcss from '@tailwindcss/vite';

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
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
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        {
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Public+Sans:wght@600&family=Sora:wght@600&display=swap',
        },
      ],
    },
  },
  css: ['~/assets/css/main.css'],
  vite: {
    plugins: [tailwindcss()],
  },
  supabase: {
    redirectOptions: {
      login: '/login',
      callback: '/confirm',
      exclude: ['/forgot-password', '/password-updated'],
    },
  },
});
