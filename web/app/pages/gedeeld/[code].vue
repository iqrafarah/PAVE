<script setup lang="ts">
// What someone shares with you through PAVE, without an account. First you see that your look is written down and can
// say who you are; then what was shared, as long as it is not paused, taken back or ended.
definePageMeta({ layout: 'public' });
useHead({ title: 'Gedeeld via PAVE', meta: [{ name: 'robots', content: 'noindex, nofollow' }] });

const code = String(useRoute().params.code ?? '').toLowerCase();
const { view, failed, loading, open } = useShareView(code);
const name = ref('');
const organisation = ref('');
const opened = computed(() => view.value !== null);

const until = computed(() =>
  view.value?.expiresAt
    ? new Date(view.value.expiresAt).toLocaleDateString('nl-NL', { day: 'numeric', month: 'long', year: 'numeric' })
    : '',
);
const groups = computed(() => {
  const items = view.value?.items ?? [];
  return Object.entries(CATEGORY_TITLES)
    .map(([category, title]) => ({ title, items: items.filter((item) => item.category === category) }))
    .filter((group) => group.items.length > 0);
});

const STATE_TEXT: Record<string, { title: string; message: string }> = {
  paused: { title: 'Even niet te zien', message: 'Degene die dit deelde, heeft het gepauzeerd. Probeer het later opnieuw.' },
  revoked: { title: 'Niet meer gedeeld', message: 'Degene die dit deelde, heeft het ingetrokken.' },
  expired: { title: 'Niet meer te zien', message: 'De tijd waarin je mocht kijken, is voorbij.' },
  unknown: { title: 'Deze link bestaat niet', message: 'Controleer of je de hele link hebt.' },
};

function look() {
  open({ name: name.value || undefined, organisation: organisation.value || undefined });
}

const itemCount = computed(() => view.value?.items?.length ?? 0);
const verifiedCount = computed(() => view.value?.items?.filter((item) => item.verified).length ?? 0);
const fileCount = computed(() => view.value?.items?.reduce((sum, item) => sum + (item.files?.length ?? 0), 0) ?? 0);
const expanded = ref(new Set<string>());

function toggle(id: string) {
  const next = new Set(expanded.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  expanded.value = next;
}

function verifiedOn(date: string) {
  return new Date(date).toLocaleDateString('nl-NL', { day: 'numeric', month: 'long', year: 'numeric' });
}

async function download(kind: 'cv' | 'letter') {
  // Downloading is written down as well; the link from that answer saves the file.
  const fresh = await open({ name: name.value || undefined, organisation: organisation.value || undefined }, 'download');
  const document = fresh?.documents?.find((doc) => doc.kind === kind);
  if (document) window.location.href = document.url;
}
</script>

<template>
  <div class="flex flex-col gap-5">
    <template v-if="!opened">
      <section class="rounded-2xl border border-card-border bg-panel p-5">
        <h1 class="font-heading text-xl font-semibold text-heading">Iemand deelt gegevens met je</h1>
        <p class="mt-2 text-sm text-subtle">
          Via PAVE, tijdelijk en alleen wat diegene heeft gekozen. Je bezoek wordt bijgehouden, zodat diegene ziet dat je
          hebt gekeken. Je naam invullen hoeft niet.
        </p>
        <form class="mt-4 flex flex-col gap-3" @submit.prevent="look">
          <label class="flex flex-col gap-1 text-sm font-medium text-ink">
            Je naam
            <input v-model="name" maxlength="80" autocomplete="name" class="rounded-xl border border-field-line bg-panel px-3 py-2.5 text-base" placeholder="Bijvoorbeeld: Sanne de Vries" />
          </label>
          <label class="flex flex-col gap-1 text-sm font-medium text-ink">
            Je organisatie
            <input v-model="organisation" maxlength="80" autocomplete="organization" class="rounded-xl border border-field-line bg-panel px-3 py-2.5 text-base" placeholder="Bijvoorbeeld: Kade Consultancy" />
          </label>
          <button type="submit" :disabled="loading" class="mt-1 rounded-full bg-brand px-5 py-3 font-semibold text-white disabled:opacity-60">
            {{ loading ? 'Even laden…' : 'Bekijk' }}
          </button>
          <p v-if="failed" class="text-sm text-red-700" role="alert">Dat lukte niet. Probeer het zo opnieuw.</p>
        </form>
      </section>
    </template>

    <template v-else-if="view && view.state !== 'active'">
      <LayoutEmptyState icon="lock" :title="STATE_TEXT[view.state]?.title ?? ''" :message="STATE_TEXT[view.state]?.message ?? ''" />
    </template>

    <template v-else-if="view">
      <section class="rounded-2xl bg-tint p-4 text-sm text-ink">
        Je kijkt tijdelijk mee tot en met <strong>{{ until }}</strong>.
        {{ view.allowsDownload ? 'Je mag het cv en de brief downloaden.' : 'Je mag alleen kijken, niet downloaden.' }}
        Bewaar niets wat je niet nodig hebt.
      </section>

      <section class="relative overflow-hidden rounded-3xl border border-card-border bg-panel p-6">
        <div class="absolute inset-x-0 top-0 h-1.5 bg-brand" aria-hidden="true" />
        <div class="flex items-center gap-4">
          <img
            v-if="view.profile?.photo"
            :src="view.profile.photo"
            alt=""
            width="80"
            height="80"
            class="size-20 shrink-0 rounded-full object-cover ring-4 ring-tint"
          />
          <div v-else class="flex size-20 shrink-0 items-center justify-center rounded-full bg-tint text-brand" aria-hidden="true">
            <LayoutPaveIcon name="person" class="size-9" />
          </div>
          <div class="min-w-0">
            <h1 class="font-heading text-2xl font-semibold text-heading break-words">{{ view.profile?.name }}</h1>
            <p v-if="view.profile?.headline" class="mt-0.5 font-medium text-brand">{{ view.profile.headline }}</p>
            <p v-if="view.profile?.email" class="mt-0.5 text-sm text-subtle break-all">{{ view.profile.email }}</p>
          </div>
        </div>
        <p v-if="view.profile?.summary" class="mt-5 rounded-2xl bg-canvas p-4 text-base text-ink">{{ view.profile.summary }}</p>
        <ul class="mt-5 flex flex-wrap gap-2 text-xs font-medium">
          <li v-if="verifiedCount" class="flex items-center gap-1.5 rounded-full bg-brand px-3 py-1 text-white">
            <LayoutPaveIcon name="check" class="size-3.5" /> {{ verifiedCount }} geverifieerd
          </li>
          <li class="rounded-full bg-tint px-3 py-1 text-ink">{{ itemCount === 1 ? '1 bewijsstuk' : `${itemCount} bewijsstukken` }}</li>
          <li v-if="fileCount" class="rounded-full bg-tint px-3 py-1 text-ink">{{ fileCount === 1 ? '1 bestand' : `${fileCount} bestanden` }} om te openen</li>
        </ul>
        <p v-if="view.purpose" class="mt-4 text-sm text-subtle">{{ view.purpose }}</p>
      </section>

      <section v-if="view.documents?.length" class="rounded-2xl border border-card-border bg-panel p-5">
        <h2 class="text-xs font-semibold uppercase tracking-wide text-muted">Cv en brief</h2>
        <ul class="mt-3 flex flex-col gap-2">
          <li v-for="doc in view.documents" :key="doc.kind" class="flex items-center justify-between gap-3">
            <a :href="doc.url" target="_blank" rel="noopener" class="font-medium text-brand underline">
              {{ doc.kind === 'cv' ? 'Bekijk het cv (pdf)' : 'Bekijk de brief (pdf)' }}
            </a>
            <button v-if="view.allowsDownload" class="flex items-center gap-1 text-sm font-medium text-brand" @click="download(doc.kind)">
              <LayoutPaveIcon name="download" class="size-4" /> Download
            </button>
          </li>
        </ul>
        <p class="mt-3 text-xs text-muted">Een link werkt een paar minuten; laad de pagina opnieuw als hij verlopen is.</p>
      </section>

      <section v-if="view.letter?.paragraphs?.length" class="rounded-2xl border border-card-border bg-panel p-5">
        <h2 class="text-xs font-semibold uppercase tracking-wide text-muted">Motivatiebrief</h2>
        <div class="mt-3 flex flex-col gap-3 text-base text-ink">
          <p v-if="view.letter.salutation">{{ view.letter.salutation }}</p>
          <p v-for="(paragraph, index) in view.letter.paragraphs" :key="index">{{ paragraph.text }}</p>
          <p v-if="view.letter.closing">{{ view.letter.closing }}<br />{{ view.letter.signature }}</p>
        </div>
      </section>

      <section v-for="group in groups" :key="group.title" class="rounded-3xl border border-card-border bg-panel p-2">
        <h2 class="px-3 pt-3 text-xs font-semibold uppercase tracking-wide text-muted">{{ group.title }}</h2>
        <ul class="mt-1 flex flex-col">
          <li v-for="item in group.items" :key="item.id" class="rounded-2xl">
            <button
              type="button"
              class="flex w-full items-start gap-3 rounded-2xl p-3 text-left transition-colors hover:bg-canvas focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand"
              :aria-expanded="expanded.has(item.id)"
              @click="toggle(item.id)"
            >
              <span class="min-w-0 flex-1">
                <span class="block font-semibold text-ink break-words">{{ item.title }}</span>
                <span v-if="item.organisation || period(item)" class="block text-sm text-subtle">
                  {{ [item.organisation, period(item)].filter(Boolean).join(' · ') }}
                </span>
                <span class="mt-1.5 flex flex-wrap items-center gap-2">
                  <span
                    class="rounded-full px-2.5 py-0.5 text-xs font-medium"
                    :class="item.verified ? 'bg-tint text-brand' : 'bg-tile text-subtle'"
                  >{{ item.verified ? 'Geverifieerd' : 'Niet geverifieerd' }}</span>
                  <span v-if="item.files?.length" class="text-xs font-medium text-brand">Met bestand</span>
                </span>
              </span>
              <LayoutPaveIcon name="chevronDown" class="mt-1 size-4 shrink-0 text-muted transition-transform" :class="expanded.has(item.id) ? 'rotate-180' : ''" />
            </button>
            <div v-if="expanded.has(item.id)" class="flex flex-col gap-3 px-3 pb-4">
              <p v-if="item.verification" class="flex items-center gap-1.5 rounded-xl bg-tint px-3 py-2 text-sm font-medium text-brand">
                <LayoutPaveIcon name="check" class="size-4 shrink-0" />
                Geverifieerd door {{ item.verification.by }} op {{ verifiedOn(item.verification.on) }}
              </p>
              <p v-if="item.description" class="text-sm text-ink">{{ item.description }}</p>
              <ul v-if="item.skills.length" class="flex flex-wrap gap-1.5">
                <li v-for="skill in item.skills" :key="skill" class="rounded-full bg-tint px-2.5 py-0.5 text-xs text-ink">{{ skill }}</li>
              </ul>
              <div v-for="file in item.files ?? []" :key="file.url" class="overflow-hidden rounded-2xl border border-card-border">
                <img v-if="file.mimeType.startsWith('image/')" :src="file.url" :alt="file.name" loading="lazy" class="max-h-[28rem] w-full bg-canvas object-contain" />
                <iframe v-else-if="file.mimeType === 'application/pdf'" :src="file.url" :title="file.name" class="h-[28rem] w-full bg-canvas" />
                <a :href="file.url" target="_blank" rel="noopener" class="flex items-center gap-2 px-3 py-2.5 text-sm font-medium text-brand break-all">
                  <LayoutPaveIcon name="folder" class="size-4 shrink-0" /> Open {{ file.name }}
                </a>
              </div>
              <p v-if="!item.files?.length && !item.description && !item.skills.length" class="text-sm text-subtle">
                Hier gaat geen bestand mee. Vraag het aan {{ view.profile?.name }} als je meer wilt zien.
              </p>
            </div>
          </li>
        </ul>
      </section>
      <p class="text-center text-xs text-muted">
        Geverifieerd betekent: bevestigd door de organisatie zelf, in PAVE. Niet geverifieerd is door {{ view.profile?.name }} zelf toegevoegd.
        Een bestand bekijken werkt een paar minuten; laad de pagina opnieuw als de link verlopen is.
      </p>
    </template>
  </div>
</template>
