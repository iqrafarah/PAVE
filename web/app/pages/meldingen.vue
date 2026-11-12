<script setup lang="ts">
import type { VaultItem } from '~/types/vault';

useHead({ title: 'Meldingen - PAVE' });

const vault = useVault();
const search = ref('');
const filterOpen = ref(false);
const verifiedOnly = ref(false);
const unreadOnly = ref(false);
const selectedItemId = ref<string | null>(null);
const readIds = useState<string[]>('pave-notifications-read', () => []);

// A vault confirmation is a real, account-specific notification. Until notification events are available,
// the vault remains the source of truth and the read state is kept for this browser session.
const notifications = computed(() => vault.state.value.items
  .filter((item) => item.status === 'verified' || item.status === 'rejected')
  .map((item) => ({ item, read: readIds.value.includes(item.id) }))
  .filter(({ item, read }) => (!verifiedOnly.value || item.status === 'verified') && (!unreadOnly.value || !read))
  .filter(({ item }) => {
    const query = search.value.trim().toLocaleLowerCase('nl');
    return !query || `${item.title} ${item.organisationName ?? ''}`.toLocaleLowerCase('nl').includes(query);
  })
  .sort((a, b) => b.item.updatedAt.localeCompare(a.item.updatedAt)));

const unreadCount = computed(() => vault.state.value.items.filter((item) =>
  (item.status === 'verified' || item.status === 'rejected') && !readIds.value.includes(item.id),
).length);

function openNotification(item: VaultItem) {
  if (!readIds.value.includes(item.id)) readIds.value = [...readIds.value, item.id];
  selectedItemId.value = item.id;
}

onMounted(() => vault.load());
</script>

<template>
  <main class="flex min-h-0 flex-1 flex-col overflow-y-auto bg-surface">
    <header class="flex shrink-0 items-center gap-2 px-4 pt-7.5 sm:px-13.25">
      <LayoutMenuLogo />
      <AylaSlashIcon class="h-7.5 w-4.5" />
      <h1 class="text-3xl font-semibold text-brand">Meldingen</h1>
    </header>

    <section class="mx-auto flex w-full max-w-187.5 flex-1 flex-col px-4 pb-10 pt-7 sm:px-8">
      <div class="mb-5">
        <h2 class="font-heading text-xl font-semibold text-heading">Je meldingen</h2>
        <p class="mt-1 text-sm text-muted">Alles wat jouw aandacht nodig heeft.</p>
      </div>

      <div class="mb-4 flex items-center gap-2 rounded-full bg-white/70 p-1" role="tablist" aria-label="Meldingen filteren">
        <button type="button" role="tab" :aria-selected="!unreadOnly" class="rounded-full px-4 py-2 text-sm font-semibold" :class="!unreadOnly ? 'bg-brand text-white' : 'text-muted hover:bg-surface'" @click="unreadOnly = false">Alle meldingen</button>
        <button type="button" role="tab" :aria-selected="unreadOnly" class="rounded-full px-4 py-2 text-sm font-semibold" :class="unreadOnly ? 'bg-brand text-white' : 'text-muted hover:bg-surface'" @click="unreadOnly = true">Ongelezen ({{ unreadCount }})</button>
      </div>

      <div class="mb-5 flex gap-2">
        <label class="flex min-w-0 flex-1 items-center gap-2 rounded-xl border border-card-border bg-white px-3 py-2.5">
          <VaultIcon src="/images/vault/toolbar-search.svg" class="size-4 shrink-0 text-muted" />
          <input v-model="search" type="search" placeholder="Zoek in meldingen" class="min-w-0 flex-1 bg-transparent text-sm text-heading outline-none placeholder:text-muted" />
        </label>
        <button type="button" aria-label="Meldingen filteren" :aria-expanded="filterOpen" class="flex size-11 items-center justify-center rounded-xl bg-tint text-brand hover:bg-badge" @click="filterOpen = !filterOpen">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="size-5" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M4 5h16l-6.5 7.5v5l-3 1.5v-6.5L4 5Z" /></svg>
        </button>
      </div>

      <div v-if="filterOpen" class="mb-5 rounded-2xl border border-card-border bg-white p-4">
        <h3 class="font-heading font-semibold text-heading">Meldingen filteren</h3>
        <p class="mt-1 text-xs text-muted">Kies welke meldingen je wilt zien.</p>
        <label class="mt-4 flex cursor-pointer items-center gap-3 rounded-xl bg-surface p-3 text-sm text-heading">
          <input v-model="verifiedOnly" type="checkbox" class="accent-brand" />
          <span class="flex-1"><strong class="block">Verificatie</strong><span class="text-xs text-muted">Bewijzen die zijn beoordeeld</span></span>
        </label>
      </div>

      <div v-if="vault.state.value.status === 'loading'" role="status" class="rounded-2xl bg-white p-5 text-sm text-muted">Meldingen laden…</div>
      <div v-else-if="vault.state.value.status === 'failed'" role="alert" class="rounded-2xl bg-white p-5 text-sm text-danger">
        Je meldingen konden niet worden geladen. <button type="button" class="font-semibold underline" @click="vault.retry()">Opnieuw proberen</button>
      </div>
      <div v-else-if="notifications.length" class="flex flex-col gap-2">
        <p class="mb-1 text-xs font-semibold text-muted">Verificaties <span class="float-right font-normal">{{ notifications.length }} meldingen</span></p>
        <button v-for="entry in notifications" :key="entry.item.id" type="button" class="flex w-full items-center gap-3 rounded-2xl border border-card-border bg-white p-3.5 text-left transition hover:border-brand/30 hover:shadow-sm" @click="openNotification(entry.item)">
          <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-tint text-brand">
            <VaultIcon :src="entry.item.status === 'verified' ? '/images/vault/status-verified.svg' : '/images/vault/status-rejected.svg'" class="size-5" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-semibold text-heading">{{ entry.item.status === 'verified' ? 'Bewijs geverifieerd' : 'Verificatie bijgewerkt' }}</span>
            <span class="mt-0.5 block truncate text-sm text-heading">{{ entry.item.title }}<template v-if="entry.item.organisationName"> · {{ entry.item.organisationName }}</template></span>
            <span class="mt-1 block text-xs text-muted">{{ new Date(entry.item.updatedAt).toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' }) }}</span>
          </span>
          <span v-if="!entry.read" class="size-2 shrink-0 rounded-full bg-brand" aria-label="Ongelezen" />
          <span class="hidden text-xs font-semibold text-brand sm:block">Bekijk bewijs <span aria-hidden="true">→</span></span>
        </button>
      </div>
      <div v-else class="flex flex-1 flex-col items-center justify-center py-14 text-center">
        <LayoutEmptyState icon="mailOpen" :title="search || unreadOnly || verifiedOnly ? 'Geen meldingen gevonden' : 'Je hebt geen meldingen'" message="Als een bewijs in je kluis is geverifieerd of bijgewerkt, zie je dat hier." />
      </div>
    </section>

    <VaultItemDialog :item-id="selectedItemId" @close="selectedItemId = null" @edit="selectedItemId = null" />
  </main>
</template>
