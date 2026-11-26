<script setup lang="ts">
// The job fair of the demo: every (fictional) employer with the QR code of its stand, to scan with PAVE.
definePageMeta({ layout: 'public' });
useHead({ title: 'Banenbeurs · PAVE' });
const { data: employers, error } = await useAsyncData('fair', () => loadFairEmployers(), { server: false });
</script>

<template>
  <div class="flex flex-col gap-5">
    <section>
      <h1 class="font-heading text-2xl font-semibold text-heading">Banenbeurs</h1>
      <p class="mt-1 text-sm text-subtle">
        Scan de code van een stand met PAVE: je ziet de werkgever en zijn vacatures, en je kunt je profiel met hem delen.
        Deze werkgevers zijn verzonnen voor de demo.
      </p>
    </section>
    <LayoutEmptyState v-if="error" icon="userGroup" title="De beurs kon niet laden" message="Probeer het zo opnieuw." />
    <ul class="grid gap-4 sm:grid-cols-2">
      <li v-for="employer in employers ?? []" :key="employer.slug" class="flex flex-col items-center gap-3 rounded-2xl border border-card-border bg-panel p-5 text-center">
        <p class="font-heading text-lg font-semibold text-heading">{{ employer.name }}</p>
        <p class="text-sm text-subtle">{{ employer.stand }}</p>
        <img :src="qrImage(`/werkgever/${employer.slug}`)" :alt="`QR-code van ${employer.name}`" width="200" height="200" class="size-50 rounded-xl bg-white" />
        <NuxtLink :to="`/werkgever/${employer.slug}`" class="text-sm font-medium text-brand underline">Bekijk de werkgever</NuxtLink>
      </li>
    </ul>
  </div>
</template>
