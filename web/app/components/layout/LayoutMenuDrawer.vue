<script setup lang="ts">
// The menu on small screens (iOS MainMenuDrawer with MainSidebar style .drawer): a panel against the left edge over
// the dimmed screen. PAVE and the bell at the top, the places, and at the bottom "Nieuw gesprek" and your account.
// Opened only with the PAVE logo at the top of a screen. Escape, a click next to it or a place closes it.
const route = useRoute();
const router = useRouter();
const conversation = useAylaConversation();
const { isMenuOpen, closeMenu } = useMainMenu();
const { openPanel } = useAylaPanel();

// On Ayla's screens the chat history is part of the menu: the logo is the only way to open a sidebar.
const showsChats = computed(() => route.meta.showsChats === true);

const panelRef = useTemplateRef<HTMLElement>('panel');
const FOCUSABLE = 'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])';

function hasPage(path: string) {
  return path === '/' || hasPageAt(router.getRoutes(), path);
}

function getFocusable() {
  return Array.from(panelRef.value?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? []);
}

function close() {
  closeMenu();
  document.querySelector<HTMLElement>('[data-menu-opener]')?.focus();
}

// Keeps Tab inside the menu while it is open.
function trapFocus(event: KeyboardEvent) {
  if (event.key !== 'Tab') return;
  const focusable = getFocusable();
  const first = focusable[0];
  const last = focusable.at(-1);
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last?.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first?.focus();
  }
}

function openChats() {
  closeMenu();
  openPanel();
}

async function startNewConversation() {
  closeMenu();
  conversation.startNew();
  await navigateTo('/');
}

watch(isMenuOpen, async (isOpen) => {
  if (!isOpen) return;
  await nextTick();
  getFocusable()[0]?.focus();
});
// Going to another place closes the menu.
watch(() => route.fullPath, closeMenu);
</script>

<template>
  <div v-if="isMenuOpen" class="md:hidden">
    <button
      type="button"
      tabindex="-1"
      :aria-label="MENU_CLOSE"
      class="fixed inset-0 z-40 bg-ink/20"
      @click="close"
    />
    <nav
      ref="panel"
      :aria-label="MENU_LABEL"
      role="dialog"
      aria-modal="true"
      class="fixed inset-y-0 left-0 z-50 flex w-75 max-w-full flex-col border-r border-rail-line bg-surface px-4 pb-4 pt-1.5 shadow-xl"
      @keydown.esc="close"
      @keydown="trapFocus"
    >
      <div class="flex min-h-11 items-center gap-3 pb-5">
        <LayoutPaveLogo class="ml-3 h-6 w-11.5" />
        <span class="flex-1" />
        <NuxtLink
          to="/meldingen"
          :aria-current="route.path === '/meldingen' ? 'page' : undefined"
          :class="route.path === '/meldingen' ? 'ring-2 ring-brand' : ''"
          class="flex size-11 items-center justify-center rounded-full bg-tile text-brand focus-visible:outline-2 focus-visible:outline-brand"
        >
          <LayoutPaveIcon name="bell" class="size-5" />
          <span class="sr-only">{{ MENU_NOTIFICATIONS }}</span>
        </NuxtLink>
      </div>

      <ul class="flex min-h-0 flex-1 flex-col gap-1 overflow-y-auto pb-4">
        <li v-for="place in MAIN_PLACES" :key="place.label">
          <NuxtLink
            v-if="hasPage(place.path)"
            :to="place.path"
            :aria-current="isPlaceActive(place, route.path) ? 'page' : undefined"
            :class="isPlaceActive(place, route.path) ? 'bg-tint text-brand' : 'text-heading hover:bg-tile'"
            class="flex min-h-12 items-center gap-3.5 rounded-xl px-3 text-base font-semibold focus-visible:outline-2 focus-visible:outline-brand"
          >
            <span class="flex size-6 items-center justify-center text-brand" aria-hidden="true">
              <LayoutAylaGlyph v-if="place.icon === 'ayla'" class="h-4.25 w-3.75" />
              <LayoutPaveIcon v-else :name="place.icon" class="size-5" />
            </span>
            {{ place.label }}
          </NuxtLink>
          <button
            v-else
            type="button"
            disabled
            class="flex min-h-12 w-full cursor-not-allowed items-center gap-3.5 rounded-xl px-3 text-base font-semibold text-ink-soft"
          >
            <span class="flex size-6 items-center justify-center text-brand" aria-hidden="true">
              <LayoutPaveIcon v-if="place.icon !== 'ayla'" :name="place.icon" class="size-5" />
            </span>
            {{ place.label }}
            <span class="sr-only">({{ AYLA_NOT_AVAILABLE_YET }})</span>
          </button>
        </li>
        <li v-if="showsChats">
          <button
            type="button"
            class="flex min-h-12 w-full items-center gap-3.5 rounded-xl px-3 text-base font-semibold text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-brand"
            @click="openChats"
          >
            <span class="flex size-6 items-center justify-center text-brand" aria-hidden="true">
              <LayoutPaveIcon name="chat" class="size-5" />
            </span>
            {{ MENU_CHATS }}
          </button>
        </li>
      </ul>

      <div class="flex items-center gap-3">
        <button
          type="button"
          class="flex min-h-11 flex-1 items-center justify-center gap-2 rounded-full bg-brand px-3.5 text-base font-semibold text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="startNewConversation"
        >
          <LayoutPaveIcon name="pencil" class="size-5" />
          {{ MENU_NEW_CONVERSATION }}
        </button>
        <LayoutAccountMenu align="end" />
      </div>
    </nav>
  </div>
</template>
