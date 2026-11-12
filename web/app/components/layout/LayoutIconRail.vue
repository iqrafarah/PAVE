<script setup lang="ts">
// The rail on wide screens: the same places and icons as the menu on small screens and on the iPhone
// (MAIN_PLACES, the Figma icons from the iPhone app). The PAVE logo opens the chat history.
const route = useRoute();
const router = useRouter();
const { isCollapsed, toggleFromLogo } = useAylaPanel();

const hasChats = computed(() => route.meta.showsChats === true);
const isChatsOpen = computed(() => hasChats.value && !isCollapsed.value);

const SETTINGS_PATH = '/instellingen';
const LATER_PLACES = MAIN_PLACES.filter((place) => place.icon !== 'ayla');
const aylaPlace = MAIN_PLACES[0];

// "Wat Ayla over je weet" is part of the settings, as on iOS.
const isSettingsActive = computed(() => route.path.startsWith(SETTINGS_PATH) || route.path === MEMORY_PAGE_PATH);
const isAylaActive = computed(() => (aylaPlace ? isPlaceActive(aylaPlace, route.path) : false));

function hasPage(path: string) {
  return hasPageAt(router.getRoutes(), path);
}
</script>

<template>
  <nav
    aria-label="Hoofdmenu"
    class="flex w-18 shrink-0 flex-col items-center border-r border-rail-line bg-surface pb-4 pt-3.25"
  >
    <!-- The PAVE logo is the only thing that opens (and closes) the chat history. -->
    <button
      type="button"
      :aria-label="isChatsOpen ? AYLA_CLOSE_PANEL : AYLA_OPEN_CHATS"
      :aria-expanded="isChatsOpen"
      class="flex h-12.25 w-12.75 items-center justify-center rounded-md bg-tint hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-brand"
      data-panel-opener
      @click="toggleFromLogo(hasChats)"
    >
      <LayoutPaveLogo decorative class="h-5.5 w-10.5" />
    </button>

    <ul class="mt-5.25 flex flex-col gap-3.75">
      <li>
        <NuxtLink
          to="/"
          :aria-current="isAylaActive ? 'page' : undefined"
          title="Ayla"
          :class="isAylaActive ? 'border-brand bg-brand text-white' : 'border-tile bg-tile text-brand'"
          class="flex h-9.5 w-10.25 items-center justify-center rounded-lg border-2 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          <LayoutAylaGlyph class="h-4.25 w-3.75" />
          <span class="sr-only">Ayla</span>
        </NuxtLink>
      </li>
      <li v-for="place in LATER_PLACES" :key="place.label">
        <NuxtLink
          v-if="hasPage(place.path)"
          :to="place.path"
          :title="place.label"
          :aria-current="isPlaceActive(place, route.path) ? 'page' : undefined"
          :class="isPlaceActive(place, route.path) ? 'bg-brand text-white' : 'bg-tile text-brand'"
          class="flex h-9.5 w-10.25 items-center justify-center rounded-lg focus-visible:outline-2 focus-visible:outline-brand"
        >
          <LayoutPaveIcon v-if="place.icon !== 'ayla'" :name="place.icon" class="size-5" />
          <span class="sr-only">{{ place.label }}</span>
        </NuxtLink>
        <button
          v-else
          type="button"
          disabled
          :title="`${place.label}: ${AYLA_NOT_AVAILABLE_YET}`"
          class="flex h-9.5 w-10.25 cursor-not-allowed items-center justify-center rounded-lg bg-tile text-heading"
        >
          <LayoutPaveIcon v-if="place.icon !== 'ayla'" :name="place.icon" class="size-5" />
          <span class="sr-only">{{ place.label }} ({{ AYLA_NOT_AVAILABLE_YET }})</span>
        </button>
      </li>
    </ul>

    <div class="mt-auto flex flex-col items-center gap-3.5">
      <NuxtLink
        :to="SETTINGS_PATH"
        :aria-current="isSettingsActive ? 'page' : undefined"
        :class="isSettingsActive ? 'bg-brand text-white' : 'bg-tile text-brand'"
        class="flex size-9 items-center justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        :title="SETTINGS_TITLE"
      >
        <LayoutPaveIcon name="settings" class="size-6" />
        <span class="sr-only">{{ SETTINGS_TITLE }}</span>
      </NuxtLink>
      <NuxtLink
        to="/meldingen"
        :title="MENU_NOTIFICATIONS"
        :aria-current="route.path === '/meldingen' ? 'page' : undefined"
        :class="route.path === '/meldingen' ? 'bg-brand text-white' : 'bg-tile text-brand'"
        class="flex size-9 items-center justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      >
        <LayoutPaveIcon name="bell" class="size-5" />
        <span class="sr-only">{{ MENU_NOTIFICATIONS }}</span>
      </NuxtLink>
      <!-- Your photo, or the first letter of your name when there is no photo yet (iOS AccountBadge). -->
      <LayoutAccountMenu class="mt-0.75" />
    </div>
  </nav>
</template>
