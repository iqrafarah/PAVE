<script setup lang="ts">
// An employer at a fair, as its QR code opens on any phone. In PAVE the same code opens their card, where you keep
// their vacancies and share your profile with them.
definePageMeta({ layout: 'public' });
const slug = String(useRoute().params.slug ?? '');
const { data: employers, error } = await useAsyncData(`fair-${slug}`, () => loadFairEmployers(slug), { server: false });
const employer = computed(() => employers.value?.[0]);
useHead(() => ({ title: employer.value ? `${employer.value.name} · PAVE` : 'Werkgever · PAVE' }));
</script>

<template>
  <div class="flex flex-col gap-5">
    <LayoutEmptyState v-if="error" icon="briefcase" title="Niet gevonden" message="Deze werkgever staat niet op de beurs." />
    <template v-else-if="employer">
      <p v-if="employer.is_example" class="rounded-2xl bg-tint p-4 text-sm text-ink">
        Voorbeeldwerkgever: verzonnen voor de demo van de banenbeurs.
      </p>
      <section class="rounded-2xl border border-card-border bg-panel p-5">
        <h1 class="font-heading text-2xl font-semibold text-heading">{{ employer.name }}</h1>
        <p class="text-sm text-subtle">{{ [employer.city, employer.stand].filter(Boolean).join(' · ') }}</p>
        <p class="mt-3 text-base text-ink">{{ employer.about }}</p>
      </section>
      <section v-if="employer.vacancies.length" class="rounded-2xl border border-card-border bg-panel p-5">
        <h2 class="text-xs font-semibold uppercase tracking-wide text-muted">Vacatures</h2>
        <ul class="mt-3 flex flex-col divide-y divide-line">
          <li v-for="vacancy in employer.vacancies" :key="vacancy.id" class="py-3 first:pt-0 last:pb-0">
            <p class="font-semibold text-ink">{{ vacancy.title }}</p>
            <p v-if="vacancy.summary" class="text-sm text-subtle">{{ vacancy.summary }}</p>
          </li>
        </ul>
      </section>
      <p class="text-center text-sm text-subtle">Scan deze QR-code met PAVE om de vacatures te bewaren en je profiel te delen.</p>
    </template>
  </div>
</template>
